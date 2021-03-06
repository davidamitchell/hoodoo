require 'spec_helper'
require 'active_record'

describe Hoodoo::ActiveRecord::Finder do
  before :all do
    spec_helper_silence_stdout() do
      ActiveRecord::Migration.create_table( :r_spec_model_finder_tests, :id => false ) do | t |
        t.text :id
        t.text :uuid
        t.text :code
        t.text :field_one
        t.text :field_two
        t.text :field_three

        t.timestamps
      end
    end

    class RSpecModelFinderTest < ActiveRecord::Base
      include Hoodoo::ActiveRecord::Finder

      self.primary_key = :id
      acquire_with :uuid, :code

      # These forms follow quite closely the RDoc comments in
      # the finder.rb source.

      ARRAY_MATCH = Proc.new { | attr, value |
        [ { attr => [ value ].flatten } ]
      }

      # Pretend security scoping that only finds things with
      # a UUID and code coming in from the session, for secured
      # searches. Note intentional mix of Symbols and Strings.

      secure_with(
        'uuid' => :authorised_uuids, # Array
        :code => 'authorised_code'   # Single item
      )

      # Deliberate mixture of symbols and strings.

      search_with(
        'field_one' => nil,
        :field_two => Proc.new { | attr, value |
          [ "#{ attr } ILIKE ?", value ]
        },
        :field_three => ARRAY_MATCH
      )

      filter_with(
        :field_one => ARRAY_MATCH,
        :field_two => nil,
        'field_three' => Proc.new { | attr, value |
          [ "#{ attr } ILIKE ?", value ]
        }
      )
    end

    class RSpecModelFinderTestWithDating < ActiveRecord::Base
      self.primary_key = :id
      self.table_name = :r_spec_model_finder_tests

      include Hoodoo::ActiveRecord::Finder
      include Hoodoo::ActiveRecord::Dated
    end

    class RSpecModelFinderTestWithHelpers < ActiveRecord::Base
      include Hoodoo::ActiveRecord::Finder

      self.primary_key = :id

      self.table_name = :r_spec_model_finder_tests
      sh              = Hoodoo::ActiveRecord::Finder::SearchHelper

      search_with(
        'mapped_code'     => sh.cs_match( 'code' ),
        :mapped_field_one => sh.ci_match_generic( 'field_one' ),
        :wild_field_one   => sh.ciaw_match_generic( 'field_one '),
        :field_two        => sh.cs_match_csv(),
        'field_three'     => sh.cs_match_array()
      )

      filter_with(
        'mapped_code'     => sh.cs_match( 'code' ),
        :mapped_field_one => sh.ci_match_postgres( 'field_one' ),
        :wild_field_one   => sh.ciaw_match_postgres( 'field_one '),
        :field_two        => sh.cs_match_csv(),
        'field_three'     => sh.cs_match_array()
      )
    end
  end

  before :each do
    @a = RSpecModelFinderTest.new
    @a.id = "one"
    @a.code = 'A' # Must be set else SQLite fails to find this if you search for "code != 'C'" (!)
    @a.field_one = 'group 1'
    @a.field_two = 'two a'
    @a.field_three = 'three a'
    @a.save!
    @id = @a.id

    @b = RSpecModelFinderTest.new
    @b.id = "two"
    @b.uuid = Hoodoo::UUID.generate
    @b.code = 'B'
    @b.field_one = 'group 1'
    @b.field_two = 'two b'
    @b.field_three = 'three b'
    @b.save!
    @uuid = @b.uuid

    @c = RSpecModelFinderTest.new
    @c.id = "three"
    @c.code = 'C'
    @c.field_one = 'group 2'
    @c.field_two = 'two c'
    @c.field_three = 'three c'
    @c.save!
    @code = @c.code

    @a_wh = RSpecModelFinderTestWithHelpers.find( @a.id )
    @b_wh = RSpecModelFinderTestWithHelpers.find( @b.id )
    @c_wh = RSpecModelFinderTestWithHelpers.find( @c.id )

    @list_params = Hoodoo::Services::Request::ListParameters.new
  end

  # ==========================================================================

  context 'acquire' do
    it 'finds from the class' do
      found = RSpecModelFinderTest.acquire( @id )
      expect( found ).to eq(@a)

      found = RSpecModelFinderTest.acquire( @uuid )
      expect( found ).to eq(@b)

      found = RSpecModelFinderTest.acquire( @code )
      expect( found ).to eq(@c)
    end

    it 'finds with a chain' do
      finder = RSpecModelFinderTest.where( :field_one => 'group 1' )

      found = finder.acquire( @id )
      expect( found ).to eq(@a)

      found = finder.acquire( @uuid )
      expect( found ).to eq(@b)

      found = finder.acquire( @code )
      expect( found ).to eq(nil) # Not in 'group 1'
    end

    # previously the finder would always cause an extra
    # call to the database to preform a count
    #
    it 'does not do excessive database calls' do

      count = count_database_calls_in do
        found = RSpecModelFinderTest.acquire( @id )
        expect( found ).to eq(@a)
      end
      # the id will be the first searched in the finder
      #  therefore only one call will be made
      expect( count ).to eq( 1 )

      count = count_database_calls_in do
        found = RSpecModelFinderTest.acquire( @uuid )
        expect( found ).to eq(@b)
      end

      # the uuid will be the second searched in the finder
      #  therefore two calls will be made, one for the
      #  id and one for the uuid
      expect( count ).to eq( 2 )

      count = count_database_calls_in do
        found = RSpecModelFinderTest.acquire( @code )
        expect( found ).to eq(@c)
      end

      # the code will be the third searched in the finder
      #  therefore three calls will be made, one for the
      #  id, one for the uuid and one for the code
      expect( count ).to eq( 3 )


      count = count_database_calls_in do
        found = RSpecModelFinderTest.acquire( Hoodoo::UUID.generate )
        expect( found ).to be_nil
      end

      # the finder will search all three
      expect( count ).to eq( 3 )
    end
  end

  # ==========================================================================

  context 'acquire_in' do
    before :each do
      @scoped_1 = RSpecModelFinderTest.new
      @scoped_1.id        = 'id 1'
      @scoped_1.uuid      = 'uuid 1'
      @scoped_1.code      = 'code 1'
      @scoped_1.field_one = 'scoped 1'
      @scoped_1.save!

      @scoped_2 = RSpecModelFinderTest.new
      @scoped_2.id        = 'id 2'
      @scoped_2.uuid      = 'uuid 1'
      @scoped_2.code      = 'code 2'
      @scoped_2.field_one = 'scoped 2'
      @scoped_2.save!

      @scoped_3 = RSpecModelFinderTest.new
      @scoped_3.id        = 'id 3'
      @scoped_3.uuid      = 'uuid 2'
      @scoped_3.code      = 'code 2'
      @scoped_3.field_one = 'scoped 3'
      @scoped_3.save!

      # Get a good-enough-for-test interaction which has a context
      # that contains a Session we can modify.

      @interaction = Hoodoo::Services::Middleware::Interaction.new( {}, nil )
      @interaction.context = Hoodoo::Services::Context.new(
        Hoodoo::Services::Session.new,
        @interaction.context.request,
        @interaction.context.response,
        @interaction
      )

      @context = @interaction.context
      @session = @interaction.context.session
    end

    it 'finds with secure scopes from the class' do
      @session.scoping = { :authorised_uuids => [ 'uuid 1' ], :authorised_code => 'code 1' }

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to eq( @scoped_1 )

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @session.scoping.authorised_code = 'code 2'

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to eq( @scoped_2 )

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @session.scoping.authorised_uuids = [ 'uuid 2' ]

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to eq( @scoped_3 )

      @session.scoping.authorised_uuids = [ 'uuid 1', 'uuid 2' ]

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to eq( @scoped_2 )

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.acquire_in( @context )
      expect( found ).to eq( @scoped_3 )
    end

    it 'finds with secure scopes with a chain' do
      @session.scoping = { :authorised_uuids => [ 'uuid 1' ], :authorised_code => 'code 1' }

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_1.field_one ).acquire_in( @context )
      expect( found ).to eq( @scoped_1 )

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_1.field_one + '!' ).acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_2.field_one ).acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_3.field_one ).acquire_in( @context )
      expect( found ).to be_nil

      @session.scoping.authorised_uuids = [ 'uuid 1', 'uuid 2' ]
      @session.scoping.authorised_code  = 'code 2'

      @context.request.uri_path_components = [ @scoped_1.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_1.field_one ).acquire_in( @context )
      expect( found ).to be_nil

      @context.request.uri_path_components = [ @scoped_2.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_2.field_one ).acquire_in( @context )
      expect( found ).to eq( @scoped_2 )

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_3.field_one ).acquire_in( @context )
      expect( found ).to eq( @scoped_3 )

      @context.request.uri_path_components = [ @scoped_3.id ]
      found = RSpecModelFinderTest.where( :field_one => @scoped_3.field_one + '!' ).acquire_in( @context )
      expect( found ).to be_nil
    end
  end

  # ==========================================================================

  context 'lists' do
    it 'lists with pages, offsets and counts' do
      @list_params.offset = 1 # 0 is first record
      @list_params.limit  = 1

      finder = RSpecModelFinderTest.order( :field_three => :asc ).list( @list_params )
      expect( finder ).to eq([@b])
      expect( finder.dataset_size).to eq(3)

      @list_params.offset = 1
      @list_params.limit  = 2

      finder = RSpecModelFinderTest.order( :field_three => :asc ).list( @list_params )
      expect( finder ).to eq([@b, @c])
      expect( finder.dataset_size).to eq(3)
    end
  end

  # ==========================================================================

  context 'search' do
    it 'searches without chain' do
      @list_params.search_data = {
        'field_one' => 'group 1'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@b, @a])

      @list_params.search_data = {
        'field_one' => 'group 2'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@c])

      @list_params.search_data = {
        'field_two' => 'TWO_A'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@a])

      @list_params.search_data = {
        'field_three' => [ 'three a', 'three c' ]
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@c, @a])

      @list_params.search_data = {
        'field_two' => 'two c',
        'field_three' => [ 'three a', 'three c' ]
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@c])
    end

    it 'searches with chain' do
      constraint = RSpecModelFinderTest.where( :field_one => 'group 1' )

      @list_params.search_data = {
        'field_one' => 'group 1'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([@b, @a])

      @list_params.search_data = {
        'field_one' => 'group 2'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])

      @list_params.search_data = {
        'field_two' => 'TWO_A'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([@a])

      @list_params.search_data = {
        'field_three' => [ 'three a', 'three c' ]
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([@a])

      @list_params.search_data = {
        'field_two' => 'two c',
        'field_three' => [ 'three a', 'three c' ]
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])
    end
  end

  # ==========================================================================

  context 'helper-based search' do
    it 'finds by mapped code' do
      @list_params.search_data = {
        'mapped_code' => @code
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh ] )
    end

    it 'finds by mapped field-one' do
      @list_params.search_data = {
        'mapped_field_one' => :'grOUp 1'
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @b_wh, @a_wh ] )
    end

    it 'finds by mapped, wildcard field-one' do
      @list_params.search_data = {
        'wild_field_one' => :'oUP '
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh, @b_wh, @a_wh ] )

      @list_params.search_data = {
        'wild_field_one' => :'o!p '
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [] )
    end

    it 'finds by comma-separated list' do
      @list_params.search_data = {
        'field_two' => 'two a,something else,two c,more'
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh, @a_wh ] )
    end

    it 'finds by Array' do
      @list_params.search_data = {
        'field_three' => [ 'hello', :'three b', 'three c', :there ]
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh, @b_wh ] )
    end
  end

  # ==========================================================================

  context 'filter' do
    it 'filters without chain' do
      @list_params.filter_data = {
        'field_two' => 'two a'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@c, @b])

      @list_params.filter_data = {
        'field_three' => 'three c'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@b, @a])

      @list_params.filter_data = {
        'field_one' => [ 'group 1', 'group 2' ]
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([])

      @list_params.filter_data = {
        'field_one' => [ 'group 2' ]
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@b, @a])

      @list_params.filter_data = {
        'field_one' => [ 'group 2' ],
        'field_three' => 'three a'
      }

      finder = RSpecModelFinderTest.list( @list_params )
      expect( finder ).to eq([@b])
    end

    it 'filters with chain' do

      # Remember, the constraint is *inclusive* unlike all the
      # subsequent filters which *exclude*.

      constraint = RSpecModelFinderTest.where( :field_one => 'group 2' )

      @list_params.filter_data = {
        'field_two' => 'two a'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([@c])

      @list_params.filter_data = {
        'field_three' => 'three c'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])

      @list_params.filter_data = {
        'field_one' => [ 'group 1', 'group 2' ]
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])

      @list_params.filter_data = {
        'field_one' => [ 'group 2' ]
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])

      @list_params.filter_data = {
        'field_one' => [ 'group 2' ],
        'field_three' => 'three a'
      }

      finder = constraint.list( @list_params )
      expect( finder ).to eq([])
    end
  end

  # ==========================================================================

  # This set of copy-and-modify tests based on the helper-based search tests
  # earlier seems somewhat redundant, but should anyone accidentally decouple
  # the search/filter back-end processing and introduce some sort of error at
  # a finder-level, the tests here have a chance of catching that.

  context 'helper-based filtering' do
    it 'filters by mapped code' do
      @list_params.filter_data = {
        'mapped_code' => @code
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @b_wh, @a_wh ] )
    end

    it 'filters by mapped field-one' do
      @list_params.filter_data = {
        'mapped_field_one' => :'grOUp 1'
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh ] )
    end

    it 'filters by mapped, wildcard field-one' do
      @list_params.filter_data = {
        'wild_field_one' => :'oUP '
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [] )

      @list_params.filter_data = {
        'wild_field_one' => :'o!p '
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @c_wh, @b_wh, @a_wh ] )
    end


    it 'filters by comma-separated list' do
      @list_params.filter_data = {
        'field_two' => 'two a,something else,two c,more'
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @b_wh ] )
    end

    it 'filters by Array' do
      @list_params.filter_data = {
        'field_three' => [ 'hello', :'three b', 'three c', :there ]
      }

      finder = RSpecModelFinderTestWithHelpers.list( @list_params )
      expect( finder ).to eq( [ @a_wh ] )
    end
  end

  # ==========================================================================

  context 'list_in' do
    before :each do
      @scoped_1 = RSpecModelFinderTest.new
      @scoped_1.id   = 'id 1'
      @scoped_1.uuid = 'uuid 1'
      @scoped_1.code = 'code 1'
      @scoped_1.field_one = 'scoped 1'
      @scoped_1.save!

      @scoped_2 = RSpecModelFinderTest.new
      @scoped_2.id   = 'id 2'
      @scoped_2.uuid = 'uuid 1'
      @scoped_2.code = 'code 2'
      @scoped_2.field_one = 'scoped 2'
      @scoped_2.save!

      @scoped_3 = RSpecModelFinderTest.new
      @scoped_3.id   = 'id 3'
      @scoped_3.uuid = 'uuid 2'
      @scoped_3.code = 'code 2'
      @scoped_3.field_one = 'scoped 3'
      @scoped_3.save!

      # Get a good-enough-for-test interaction which has a context
      # that contains a Session we can modify.

      @interaction = Hoodoo::Services::Middleware::Interaction.new( {}, nil )
      @interaction.context = Hoodoo::Services::Context.new(
        Hoodoo::Services::Session.new,
        @interaction.context.request,
        @interaction.context.response,
        @interaction
      )

      @context = @interaction.context
      @session = @interaction.context.session
    end

    it 'lists with secure scopes from the class' do
      @session.scoping = { :authorised_uuids => [ 'uuid 1' ], :authorised_code => 'code 1' }

      list = RSpecModelFinderTest.list_in( @context )
      expect( list ).to eq( [ @scoped_1 ] )

      @session.scoping.authorised_code = 'code 2'

      list = RSpecModelFinderTest.list_in( @context )
      expect( list ).to eq( [ @scoped_2 ] )

      @session.scoping.authorised_uuids = [ 'uuid 2' ]

      list = RSpecModelFinderTest.list_in( @context )
      expect( list ).to eq( [ @scoped_3 ] )

      @session.scoping.authorised_uuids = [ 'uuid 1', 'uuid 2' ]

      # OK, so these test 'with a chain' too... It's just convenient to (re-)cover
      # that aspect here.

      list = RSpecModelFinderTest.list_in( @context ).reorder( 'field_one' => 'asc' )
      expect( list ).to eq( [ @scoped_2, @scoped_3 ] )

      list = RSpecModelFinderTest.list_in( @context ).reorder( 'field_one' => 'desc' )
      expect( list ).to eq( [ @scoped_3, @scoped_2 ] )

      list = RSpecModelFinderTest.reorder( 'field_one' => 'asc' ).list_in( @context )
      expect( list ).to eq( [ @scoped_2, @scoped_3 ] )

      list = RSpecModelFinderTest.reorder( 'field_one' => 'desc' ).list_in( @context )
      expect( list ).to eq( [ @scoped_3, @scoped_2 ] )
    end

    it 'finds with secure scopes with a chain' do
      @session.scoping = { :authorised_uuids => [ 'uuid 1' ], :authorised_code => 'code 1' }

      list = RSpecModelFinderTest.where( :field_one => @scoped_1.field_one ).list_in( @context )
      expect( list ).to eq( [ @scoped_1 ] )

      list = RSpecModelFinderTest.where( :field_one => @scoped_1.field_one + '!' ).list_in( @context )
      expect( list ).to eq( [] )

      list = RSpecModelFinderTest.list_in( @context ).where( :field_one => @scoped_1.field_one )
      expect( list ).to eq( [ @scoped_1 ] )

      list = RSpecModelFinderTest.list_in( @context ).where( :field_one => @scoped_1.field_one + '!' )
      expect( list ).to eq( [] )

      @session.scoping.authorised_uuids = [ 'uuid 1', 'uuid 2' ]
      @session.scoping.authorised_code  = 'code 2'

      list = RSpecModelFinderTest.where( :field_one => [ @scoped_1.field_one, @scoped_2.field_one ] ).list_in( @context )
      expect( list ).to eq( [ @scoped_2 ] )

      list = RSpecModelFinderTest.list_in( @context ).where( :field_one => [ @scoped_1.field_one, @scoped_2.field_one ] )
      expect( list ).to eq( [ @scoped_2 ] )

      list = RSpecModelFinderTest.where( :field_one => [ @scoped_2.field_one, @scoped_3.field_one ] ).list_in( @context ).reorder( 'field_one' => 'asc' )
      expect( list ).to eq( [ @scoped_2, @scoped_3 ] )

      list = RSpecModelFinderTest.list_in( @context ).reorder( 'field_one' => 'asc' ).where( :field_one => [ @scoped_2.field_one, @scoped_3.field_one ] )
      expect( list ).to eq( [ @scoped_2, @scoped_3 ] )
    end
  end

  # ==========================================================================

  context 'deprecated' do
    it '#polymorphic_find calls #acquire' do
      expect( $stderr ).to receive( :puts ).once
      expect( RSpecModelFinderTest ).to receive( :acquire ).once.with( 21 )
      RSpecModelFinderTest.polymorphic_find( RSpecModelFinderTest, 21 )
    end

    it '#polymorphic_id_fields calls #acquire_with' do
      expect( $stderr ).to receive( :puts ).once
      expect( RSpecModelFinderTest ).to receive( :acquire_with ).once.with( :uuid, :code )
      RSpecModelFinderTest.polymorphic_id_fields( :uuid, :code )
    end

    it '#list_finder calls #list' do
      params = { :search => { :field_one => 'one' } }
      expect( $stderr ).to receive( :puts ).once
      expect( RSpecModelFinderTest ).to receive( :list ).once.with( params )
      RSpecModelFinderTest.list_finder( params )
    end

    it '#list_search_map calls #search_with' do
      params = { :foo => nil, :bar => nil }
      expect( $stderr ).to receive( :puts ).once
      expect( RSpecModelFinderTest ).to receive( :search_with ).once.with( params )
      RSpecModelFinderTest.list_search_map( params )
    end

    it '#list_filter_map calls #filter_with' do
      params = { :foo => nil, :bar => nil }
      expect( $stderr ).to receive( :puts ).once
      expect( RSpecModelFinderTest ).to receive( :filter_with ).once.with( params )
      RSpecModelFinderTest.list_filter_map( params )
    end
  end
end
