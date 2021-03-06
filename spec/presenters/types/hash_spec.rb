require 'spec_helper'

describe Hoodoo::Presenters::Hash do

  context 'exceptions' do
    it 'should complain about #key then #keys' do
      expect {
        class TestHashKeyKeysException < Hoodoo::Presenters::Base
          schema do
            hash :foo do
              key :one
              keys :length => 4
            end
          end
        end
      }.to raise_error( RuntimeError )
    end

    it 'should complain about #keys then #key' do
      expect {
        class TestHashKeysKeyException < Hoodoo::Presenters::Base
          schema do
            hash :foo do
              keys :length => 4
              key :one
            end
          end
        end
      }.to raise_error( RuntimeError )
    end

    it 'should complain about #keys twice' do
      expect {
        class TestHashKeysKeysException < Hoodoo::Presenters::Base
          schema do
            hash :foo do
              keys :length => 4
              keys :length => 4
            end
          end
        end
      }.to raise_error( RuntimeError )
    end
  end

  ############################################################################

  class TestHashNoKeysPresenter < Hoodoo::Presenters::Base
    schema do
      hash :specific
    end
  end

  class TestHashNoKeysPresenterRequired < Hoodoo::Presenters::Base
    schema do
      hash :specific_required, :required => true
    end
  end

  ############################################################################

  context 'no keys' do
    context '#validate' do
      it 'should return [] when valid object' do
        data = { 'specific' => { 'hello' => 'there' } }
        expect( TestHashNoKeysPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct error when data is not an object' do
        data   = { 'specific' => 'hello' }
        errors = [ {
          'code'      => 'generic.invalid_hash',
          'message'   => 'Field `specific` is an invalid hash',
          'reference' => 'specific'
        } ]

        expect( TestHashNoKeysPresenter.validate( data ).errors ).to eq( errors )
      end

      it 'should not return error when not required and absent' do
        data = { 'foo' => 'bar' }
        expect( TestHashNoKeysPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return error when required and absent' do
        data   = { 'foo' => 'bar' }
        errors = [ {
          'code'      => 'generic.required_field_missing',
          'message'   => 'Field `specific_required` is required',
          'reference' => 'specific_required'
        } ]

        expect( TestHashNoKeysPresenterRequired.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should render correctly' do
        data   = { 'specific' => { 'hello' => 'there' } }
        result = TestHashNoKeysPresenter.render( data )

        expect( result ).to eq( data )
      end

      it 'should render correctly when described hash is not required and absent' do
        data   = { 'foo' => 'bar' }
        result = TestHashNoKeysPresenter.render( data )

        expect( result ).to eq({})
      end
    end
  end

  ############################################################################

  class TestHashSpecificKeyPresenter < Hoodoo::Presenters::Base
    schema do
      hash :specific do
        key :one
        key :two do
          string :foo, :length => 10
          text :bar, :required => true
        end
        key :three do
          integer :int
          uuid :id
        end
      end
    end
  end

  ############################################################################

  context 'specific keys' do
    context '#validate' do
      it 'should return [] when valid object (1)' do
        data = { 'specific' => { 'one' => 'anything' } }
        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return [] when valid object (2)' do
        data = { 'specific' => { 'two' => { 'foo' => 'foov', 'bar' => 'barv' } } }
        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return [] when valid object (3)' do
        data = { 'specific' => { 'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } } }
        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return [] when valid object (4)' do
        data = { 'specific' => { 'one' => 'anything',
                                 'two' => { 'foo' => 'foov', 'bar' => 'barv' },
                                 'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } } }

        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct error when data is not an object' do
        data   = { 'specific' => 'hello' }
        errors = [ {
          'code'      => 'generic.invalid_hash',
          'message'   => 'Field `specific` is an invalid hash',
          'reference' => 'specific'
        } ]

        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct error when unexpected keys are present' do
        data = { 'specific' => { 'hi' => 'there',
                                 'foo' => { 'bar' => 'baz' },
                                 'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } } }
        errors = [ {
          'code'      => 'generic.invalid_hash',
          'message'   => 'Field `specific` is an invalid hash due to unrecognised keys `hi, foo`',
          'reference' => 'specific'
        } ]

        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct errors when value formats are wrong or required values are omitted' do
        data = { 'specific' => { 'three' => { 'int' => 'not an int', 'id' => 'not an id' }, 'two' => {} } }

        errors = [
          {
            'code'      => 'generic.invalid_integer',
            'message'   => 'Field `specific.three.int` is an invalid integer',
            'reference' => 'specific.three.int'
          },
          {
            'code'      => 'generic.invalid_uuid',
            'message'   => 'Field `specific.three.id` is an invalid UUID',
            'reference' => 'specific.three.id'
          },
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `specific.two.bar` is required',
            'reference' => 'specific.two.bar'
          },
        ]

        expect( TestHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should render correctly (1)' do
        data   = { 'specific' => { 'one' => 'anything' } }
        result = TestHashSpecificKeyPresenter.render( data )

        expect( result ).to eq( data )
      end

      it 'should render correctly (2)' do
        data   = { 'specific' => { 'two' => { 'foo' => 'foov', 'bar' => 'barv' } } }
        result = TestHashSpecificKeyPresenter.render( data )

        expect( result ).to eq( data )
      end

      it 'should render correctly (3)' do
        data   = { 'specific' => { 'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } } }
        result = TestHashSpecificKeyPresenter.render( data )

        expect( result ).to eq( data )
      end

      it 'should render correctly (4)' do
        data   = { 'specific' => { 'one' => 'anything',
                                   'two' => { 'foo' => 'foov', 'bar' => 'barv' },
                                   'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } } }
        result = TestHashSpecificKeyPresenter.render( data )

        expect( result ).to eq( data )
      end

      it 'should ignore unspecified entries' do
        inner = { 'one' => 'anything',
                  'two' => { 'foo' => 'foov', 'bar' => 'barv' },
                  'three' => { 'int' => 23, 'id' => Hoodoo::UUID.generate() } }

        valid = { 'specific' => inner.dup }
        data  = { 'specific' => inner.dup }

        data[ 'generic' ] = 'hello'
        data[ 'specific' ][ 'random' ] = 23

        result = TestHashSpecificKeyPresenter.render( data )

        expect( result ).to eq( valid )
      end
    end
  end

  ############################################################################

  class TestNestedHashSpecificKeyPresenter < Hoodoo::Presenters::Base
    schema do
      object :obj do
        text :obj_text
        hash :specific do
          key :two do
            string :two_key_string, :length => 10
            hash :two_key_hash do
              key :inner
              key :inner_2 do
                string :inner_2_string, :length => 4
              end
            end
          end
        end
      end
    end
  end

  ############################################################################

  context 'nested specific keys' do
    context '#validate' do
      it 'should return [] when valid object (1)' do
        data = { 'obj' => { 'specific' => {} } }
        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return [] when valid object (2)' do
        data = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'two' => {} } } }
        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return error with incorrect nested keys (1)' do
        data   = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'three' => {} } } }
        errors = [
          {
            'code'      => 'generic.invalid_hash',
            'message'   => 'Field `obj.specific` is an invalid hash due to unrecognised keys `three`',
            'reference' => 'obj.specific'
          }
        ]

        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end

      it 'should return [] when valid object (3)' do
        data = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'two' => { 'two_key_hash' => {} } } } }
        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return [] when valid object (4)' do
        data = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'two' => { 'two_key_hash' => { 'inner' => true } } } } }
        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( [] )
      end

      it 'should return error with incorrect nested keys (2)' do
        data = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'two' => { 'two_key_hash' => { 'madeup' => true } } } } }
        errors = [
          {
            'code'      => 'generic.invalid_hash',
            'message'   => 'Field `obj.specific.two.two_key_hash` is an invalid hash due to unrecognised keys `madeup`',
            'reference' => 'obj.specific.two.two_key_hash'
          }
        ]

        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end

      it 'should return error with incorrect nested values' do
        data = { 'obj' => { 'obj_text' => 'hello', 'specific' => { 'two' => { 'two_key_hash' => { 'inner_2' => { 'inner_2_string' => 'too-long-for-here' } } } } } }
        errors = [
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `obj.specific.two.two_key_hash.inner_2.inner_2_string` is longer than maximum length `4`',
            'reference' => 'obj.specific.two.two_key_hash.inner_2.inner_2_string'
          }
        ]

        expect( TestNestedHashSpecificKeyPresenter.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should render complex entity correctly' do
        valid  = { 'obj' => { 'obj_text' => 'hello',                   'specific' => { 'two' => { 'two_key_hash' => { 'inner' => 42, 'inner_2' => { 'inner_2_string' => 'ok' } } } } } }
        data   = { 'obj' => { 'obj_text' => 'hello', 'random' => true, 'specific' => { 'two' => { 'two_key_hash' => { 'inner' => 42, 'inner_2' => { 'inner_2_string' => 'ok' } } } } } }

        result = TestNestedHashSpecificKeyPresenter.render( data )
        expect( result ).to eq( valid )
      end
    end
  end

  ############################################################################

  class TestHashSpecificKeyPresenterWithRequirements < Hoodoo::Presenters::Base
    schema do
      hash :specific do
        key :one, :required => true
        key :two, :required => true do
          string :foo, :length => 10
          text :bar, :required => true
        end
      end
    end
  end

  ############################################################################

  context 'specific keys with requirements' do
    context '#validate' do
      it 'should return correct errors when keys are omitted (1)' do
        data   = { 'specific' => {} }
        errors = [
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `specific.one` is required',
            'reference' => 'specific.one'
          },
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `specific.two` is required',
            'reference' => 'specific.two'
          },
        ]

        expect( TestHashSpecificKeyPresenterWithRequirements.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct errors when keys are omitted (2)' do
        data   = { 'specific' => { 'two' => { 'foo' => 'foov' } } }
        errors = [
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `specific.two.bar` is required',
            'reference' => 'specific.two.bar'
          },
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `specific.one` is required',
            'reference' => 'specific.one'
          }
        ]

        expect( TestHashSpecificKeyPresenterWithRequirements.validate( data ).errors ).to eq( errors )
      end
    end
  end

  ############################################################################

  class TestHashSpecificKeyPresenterWithDefaults < Hoodoo::Presenters::Base
    schema do
      hash :specific_defaults, :default => { 'one' => 'anything', 'two' => { 'foo' => 'valid' }, 'ignoreme' => 'invalid' } do
        key :one, :default => { 'foo' => { 'bar' => 'baz' } }
        key :two do
          string :foo, :length => 10
          text :bar, :default => 'this is the text field for "bar"'
          integer :baz, :default => 42
        end
        key :three, :default => { 'bar' => 'for_key_three' } do
          string :foo, :length => 10
          text :bar, :default => 'this is the text field for "bar"'
          integer :baz, :default => 42
        end
      end
    end
  end

  class TestHashSpecificKeyPresenterWithDefaultsExceptHash < Hoodoo::Presenters::Base
    schema do
      hash :specific_defaults do
        key :one, :default => { 'foo' => { 'bar' => 'baz' } }
        key :two do
          string :foo, :length => 10
          text :bar, :default => 'this is the text field for "bar"'
          integer :baz, :default => 42
        end
      end
    end
  end

  ############################################################################

  context 'specific keys with defaults' do
    context '#render' do

      # The hash itself has a default set, so if the hash key is omitted we
      # expect to get the canned default hash instead.
      #
      it 'should render with correct default for whole hash (1)' do
        result = TestHashSpecificKeyPresenterWithDefaults.render( {} )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => 'anything',
            'two' => { 'foo' => 'valid', 'bar' => 'this is the text field for "bar"', 'baz' => 42 },
            'three' => { 'bar' => 'for_key_three', 'baz' => 42 }
          }
        })
      end

      # Should behave the same with 'nil'.
      #
      it 'should render with correct default for whole hash (2)' do
        result = TestHashSpecificKeyPresenterWithDefaults.render( nil )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => 'anything',
            'two' => { 'foo' => 'valid', 'bar' => 'this is the text field for "bar"', 'baz' => 42 },
            'three' => { 'bar' => 'for_key_three', 'baz' => 42 }
          }
        })
      end

      # Empty objects gain default fields, just like at the root level;
      # and key-level defaults (one is specified for key 'three') also end
      # up with field-level defaults merged (almost by accident, but it
      # makes sense to do so) - integer 'baz' has a default value of 42 as
      # a field-level default.
      #
      it 'renders an explicit empty hash with default fields' do
        data   = { 'specific_defaults' => {} }
        result = TestHashSpecificKeyPresenterWithDefaults.render( data )
        expect( result ).to eq({
          'specific_defaults' => {
            'one' => { 'foo' => { 'bar' => 'baz' } },
            'three' => { 'bar' => 'for_key_three', 'baz' => 42 }
          }
        })
      end

      # ...but explicit nil means nil.
      #
      it 'renders an explicit nil' do
        data   = { 'specific_defaults' => nil }
        result = TestHashSpecificKeyPresenterWithDefaults.render( data )
        expect( result ).to eq(data)
      end

      # One of the hash's specific keys has a defined block with some default
      # values, so if we specify an empty hash for that key, we expect it to
      # be filled in with defaults.
      #
      it 'should render with correct defaults for hash value keys' do
        data   = { 'specific_defaults' => { 'two' => {} } }
        result = TestHashSpecificKeyPresenterWithDefaults.render( data )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => { 'foo' => { 'bar' => 'baz' } },
            'two' => {
              'bar' => 'this is the text field for "bar"',
              'baz' => 42
            },
            'three' => { 'bar' => 'for_key_three', 'baz' => 42 }
          }
        })
      end

      # Take away the hash-level full default value; we expect an omitted hash
      # to be rendered with default contents.
      #
      it 'should render with correct default for keys when hash itself has no default (1)' do
        result = TestHashSpecificKeyPresenterWithDefaultsExceptHash.render( {} )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => { 'foo' => { 'bar' => 'baz' } }
          }
        })
      end

      # Should behave the same with 'nil'.
      #
      it 'should render with correct default for keys when hash itself has no default (2)' do
        result = TestHashSpecificKeyPresenterWithDefaultsExceptHash.render( nil )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => { 'foo' => { 'bar' => 'baz' } }
          }
        })
      end

      # We also expect the same result if an empty hash is provided, as with the
      # case where the hash itself had a default value.
      #
      it 'should render with correct defaults for hash keys (3)' do
        data   = { 'specific_defaults' => {} }
        result = TestHashSpecificKeyPresenterWithDefaultsExceptHash.render( data )

        expect( result ).to eq({
          'specific_defaults' => {
            'one' => { 'foo' => { 'bar' => 'baz' } }
          }
        })
      end

      # Once more, explicit nil means nil.
      #
      it 'should render with correct defaults for hash keys (4)' do
        data   = { 'specific_defaults' => nil }
        result = TestHashSpecificKeyPresenterWithDefaultsExceptHash.render( data )

        expect( result ).to eq(data)
      end
    end
  end

  ############################################################################

  class TestHashGenericKeyPresenterNoValues < Hoodoo::Presenters::Base
    schema do
      hash :generic do
        keys :length => 6
      end
    end
  end

  ############################################################################

  context 'generic keys no values' do
    context '#validate' do
      it 'should return [] when valid object' do
        data = { 'generic' => { 'one' => 'anything' } }
        expect( TestHashGenericKeyPresenterNoValues.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct errors with invalid keys' do
        data   = { 'generic' => { 'one' => 'anything',
                                  'two' => 'anything',
                                  'toolong' => 'anything',
                                  'evenlonger' => 'anything' } }
        errors = [
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.toolong` is longer than maximum length `6`',
            'reference' => 'generic.toolong'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.evenlonger` is longer than maximum length `6`',
            'reference' => 'generic.evenlonger'
          }
        ]

        expect( TestHashGenericKeyPresenterNoValues.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should render correctly' do

        # Use of "values" is important as it tests for a collision with
        # an internal same-named property. It's an implementation detail
        # which the code should deal with internally correctly, leading
        # to no disernable alteration in expected rendering for callers.

        data   = { 'generic' => { 'one'    => 'anything 1',
                                  'values' => 'should not be overwritten',
                                  'two'    => 'anything 2' } }

        result = TestHashGenericKeyPresenterNoValues.render( data )
        expect( result ).to eq( data )
      end
    end
  end

  ############################################################################

  class TestHashGenericKeyPresenterWithValues < Hoodoo::Presenters::Base
    schema do
      hash :generic do
        keys :length => 4 do
          string :foo, :length => 10
          text :bar
        end
      end
    end
  end

  ############################################################################

  context 'generic keys with values' do
    context '#validate' do
      it 'should return [] when valid object' do
        data = { 'generic' => { 'one' => { 'foo' => 'foov' } } }
        expect( TestHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct errors with invalid keys' do
        data   = { 'generic' => { 'one' => { 'foo' => 'foov' },
                                  'two' => { 'bar' => 'barv' },
                                  'toolong' => { 'foo' => 'foov' },
                                  'evenlonger' => { 'bar' => 'barv' } } }
        errors = [
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.toolong` is longer than maximum length `4`',
            'reference' => 'generic.toolong'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.evenlonger` is longer than maximum length `4`',
            'reference' => 'generic.evenlonger'
          }
        ]

        expect( TestHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct errors with invalid values' do
        data   = { 'generic' => { 'one' => { 'foo' => 'foov' },
                                  'two' => 'not-an-object' } }
        errors = [
          {
            'code'      => 'generic.invalid_object',
            'message'   => 'Field `generic.two` is an invalid object',
            'reference' => 'generic.two'
          }
        ]

        expect( TestHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct errors with invalid keys and values' do
        data   = { 'generic' => { 'one' => 'not-an-object',
                                  'two' => { 'bar' => 'barv' },
                                  'toolong' => 'not-an-object',
                                  'evenlonger' => { 'bar' => 'barv' } } }
        errors = [
          {
            'code'      => 'generic.invalid_object',
            'message'   => 'Field `generic.one` is an invalid object',
            'reference' => 'generic.one'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.toolong` is longer than maximum length `4`',
            'reference' => 'generic.toolong'
          },
          {
            'code'      => 'generic.invalid_object',
            'message'   => 'Field `generic.toolong` is an invalid object',
            'reference' => 'generic.toolong'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.evenlonger` is longer than maximum length `4`',
            'reference' => 'generic.evenlonger'
          }
        ]

        expect( TestHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should only render expected fields' do

        valid  = { 'generic' => { 'one' => {                       'foo' => '<= 10 long' }, 'values' => { 'foo' => '<= 10 2', 'bar' => 'barv'                     }, 'two' => { 'bar' => 'barv 2' } } }
        data   = { 'generic' => { 'one' => { 'random' => 'ignore', 'foo' => '<= 10 long' }, 'values' => { 'foo' => '<= 10 2', 'bar' => 'barv', 'hello' => 'there' }, 'two' => { 'bar' => 'barv 2' } } }

        result = TestHashGenericKeyPresenterWithValues.render( data )
        expect( result ).to eq( valid )
      end
    end
  end

  context 'generic keys no values' do
    context '#validate' do
      it 'should return [] when valid object' do
        data = { 'generic' => { 'one' => 'anything' } }
        expect( TestHashGenericKeyPresenterNoValues.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct errors with invalid keys' do
        data   = { 'generic' => { 'one' => 'anything',
                                  'two' => 'anything',
                                  'toolong' => 'anything',
                                  'evenlonger' => 'anything' } }
        errors = [
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.toolong` is longer than maximum length `6`',
            'reference' => 'generic.toolong'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `generic.evenlonger` is longer than maximum length `6`',
            'reference' => 'generic.evenlonger'
          }
        ]

        expect( TestHashGenericKeyPresenterNoValues.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should render correctly' do

        # Use of "values" is important as it tests for a collision with
        # an internal same-named property. It's an implementation detail
        # which the code should deal with internally correctly, leading
        # to no disernable alteration in expected rendering for callers.

        data   = { 'generic' => { 'one'    => 'anything 1',
                                  'values' => 'should not be overwritten',
                                  'two'    => 'anything 2' } }

        result = TestHashGenericKeyPresenterNoValues.render( data )
        expect( result ).to eq( data )
      end
    end
  end

  ############################################################################

  class TestNestedHashGenericKeyPresenterWithValues < Hoodoo::Presenters::Base
    schema do
      object :obj do
        hash :generic do
          keys :length => 4 do
            string :foo, :length => 10
            text :bar
            hash :baz do
              keys do
                string :inner_string, :length => 5
              end
            end
          end
        end
      end
    end
  end

  ############################################################################

  context 'nested generic keys with values' do
    context '#validate' do
      it 'should return [] when valid object' do
        data = { 'obj' => { 'generic' => { 'one' => { 'foo' => 'foov' } } } }
        expect( TestNestedHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( [] )
      end

      it 'should return correct errors with invalid keys' do
        data   = { 'obj' => { 'generic' => { 'one' => { 'foo' => 'foov' },
                                             'two' => { 'bar' => 'barv' },
                                             'toolong' => { 'foo' => 'foov' },
                                             'evenlonger' => { 'bar' => 'barv' },
                                             'ok' => { 'baz' => { 'anything' => { 'inner_string' => 'toolong' } } } } } }
        errors = [
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `obj.generic.toolong` is longer than maximum length `4`',
            'reference' => 'obj.generic.toolong'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `obj.generic.evenlonger` is longer than maximum length `4`',
            'reference' => 'obj.generic.evenlonger'
          },
          {
            'code'      => 'generic.invalid_string',
            'message'   => 'Field `obj.generic.ok.baz.anything.inner_string` is longer than maximum length `5`',
            'reference' => 'obj.generic.ok.baz.anything.inner_string'
          }
        ]

        expect( TestNestedHashGenericKeyPresenterWithValues.validate( data ).errors ).to eq( errors )
      end
    end

    context '#render' do
      it 'should only render expected fields' do

        valid  = {                 'obj' => { 'generic' => { 'one' => {                       'foo' => '<= 10 long' }, 'values' => { 'foo' => '<= 10 2', 'bar' => 'barv', 'baz' => { 'any' => {                  'inner_string' => 'hi' } }                     }, 'two' => { 'bar' => 'barv 2' } } } }
        data   = { 'number' => 42, 'obj' => { 'generic' => { 'one' => { 'random' => 'ignore', 'foo' => '<= 10 long' }, 'values' => { 'foo' => '<= 10 2', 'bar' => 'barv', 'baz' => { 'any' => { 'hi' => 'there', 'inner_string' => 'hi' } }, 'hello' => 'there' }, 'two' => { 'bar' => 'barv 2' } } } }

        result = TestNestedHashGenericKeyPresenterWithValues.render( data )
        expect( result ).to eq( valid )
      end
    end
  end

  ############################################################################

  class TestHashGenericKeyPresenterWithRequirements < Hoodoo::Presenters::Base
    schema do
      hash :generic do
        keys :length => 4, :required => true do
          string :foo, :length => 10
          text :bar, :required => true
        end
      end
    end
  end

  ############################################################################

  context 'generic keys with requirements' do
    context '#validate' do
      it 'should return [] when valid object with keys' do
        data = { 'generic' => { 'one' => { 'foo' => 'foov', 'bar' => 'hello' } } }
        expect( TestHashGenericKeyPresenterWithRequirements.validate( data ).errors ).to eq( [] )
      end

      # The Hash itself isn't required; only its keys are, so if 'nil' that
      # should not cause an error.
      #
      it 'should return [] with valid missing hash' do
        data = { 'generic' => nil }
        expect( TestHashGenericKeyPresenterWithRequirements.validate( data ).errors ).to eq( [] )
      end

      # The Hash itself isn't required; only its keys are, so if present but
      # empty (no keys), that should cause an error.
      #
      it 'should return correct errors with missing hash' do
        data   = { 'generic' => {} }
        errors = [
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `generic` is required (Hash, if present, must contain at least one key)',
            'reference' => 'generic'
          }
        ]

        expect( TestHashGenericKeyPresenterWithRequirements.validate( data ).errors ).to eq( errors )
      end

      it 'should return correct errors with missing keys in hash' do
        data   = { 'generic' => { 'one' => { 'foo' => 'foov' } } }
        errors = [
          {
            'code'      => 'generic.required_field_missing',
            'message'   => 'Field `generic.one.bar` is required',
            'reference' => 'generic.one.bar'
          }
        ]

        expect( TestHashGenericKeyPresenterWithRequirements.validate( data ).errors ).to eq( errors )
      end
    end
  end

  ############################################################################

  it 'complains about generic default keys as they are meaningless' do
    expect {
      class TestHashGenericKeyPresenterWithMeaninglessDefaults < Hoodoo::Presenters::Base
        schema do
          hash :generic_defaults do
            keys :length => 4, :default => { 'meaningless' => 'complain' } do
              text :baz
            end
          end
        end
      end
    }.to raise_error(RuntimeError)
  end

  class TestHashGenericKeyPresenterWithDefaults < Hoodoo::Presenters::Base
    schema do
      hash :generic_defaults, :default => { 'a_default_key' => { 'baz' => 'merge' }, 'a_nil_key' => nil } do
        keys :length => 4 do
          string :foo, :length => 10
          text :bar, :default => 'default for text field'
          text :baz
        end
      end
    end
  end

  class TestHashGenericKeyPresenterWithDefaultsExceptHash < Hoodoo::Presenters::Base
    schema do
      hash :generic_defaults do
        keys :length => 4 do
          string :foo, :length => 10
          text :bar, :default => 'default for text field'
          text :baz
        end
      end
    end
  end

  ############################################################################

  context 'generic keys with defaults' do
    context '#render' do

      # The hash itself has a default set, so if the hash key is omitted we
      # expect to get the canned default hash instead. This outer default is
      # rendered, so the key(s) it specifies get individually run through
      # the renderer. If the value is nil, it'll gain the whole-value default.
      # Otherwise, it gains in-block defaults (if any).
      #
      it 'should render with correct default for whole hash (1)' do
        result = TestHashGenericKeyPresenterWithDefaults.render( {} )

        expect( result ).to eq({
          'generic_defaults' => {
            'a_default_key' => { 'bar' => 'default for text field', 'baz' => 'merge' },
            'a_nil_key'     => nil
          }
        })
      end

      # Explicit nil means nil, but at the top level we have to treat it as an
      # empty hash so it'll give the same result.
      #
      it 'should render with correct default for whole hash (2)' do
        result = TestHashGenericKeyPresenterWithDefaults.render( nil )

        expect( result ).to eq({
          'generic_defaults' => {
            'a_default_key' => { 'bar' => 'default for text field', 'baz' => 'merge' },
            'a_nil_key'     => nil
          }
        })
      end

      # If we explicitly give a value for the hash, then that should override
      # the hash-wide default, even if empty...
      #
      it 'should render with correct defaults for hash keys (1)' do
        data   = { 'generic_defaults' => {} }
        result = TestHashGenericKeyPresenterWithDefaults.render( data )

        expect( result ).to eq({
          'generic_defaults' => {}
        })
      end

      # ...However explicit nil means nil...
      #
      it 'should render with correct defaults for hash keys (2)' do
        data   = { 'generic_defaults' => nil }
        result = TestHashGenericKeyPresenterWithDefaults.render( data )
        expect( result ).to eq(data)
      end

      # ...and explicitly defined keys with nil values should be nil too.
      #
      it 'should render with correct defaults for hash keys (3)' do
        data   = { 'generic_defaults' => { 'hello' => nil, 'goodbye' => {}, 'another' => { 'foo' => 'present', 'bar' => 'also present' } } }
        result = TestHashGenericKeyPresenterWithDefaults.render( data )

        expect( result ).to eq({
          'generic_defaults' => {
            'hello'   => nil,
            'goodbye' => {                     'bar' => 'default for text field' },
            'another' => { 'foo' => 'present', 'bar' => 'also present'           }
          }
        })
      end

      # No hash default now. An empty hash can only be rendered as an empty
      # hash, because we don't have any default key names or hash-wide default
      # to use as a template.
      #
      it 'should render with correct default for whole hash (1)' do
        result = TestHashGenericKeyPresenterWithDefaultsExceptHash.render( {} )
        expect( result ).to eq({})
      end

      # Should behave the same with 'nil'.
      #
      it 'should render with correct default for whole hash (2)' do
        result = TestHashGenericKeyPresenterWithDefaultsExceptHash.render( nil )
        expect( result ).to eq({})
      end

      # If we explicitly give a value for the hash, should get the empty hash
      # recorded...
      #
      it 'should render with correct defaults for hash keys (1)' do
        data   = { 'generic_defaults' => {} }
        result = TestHashGenericKeyPresenterWithDefaultsExceptHash.render( data )
        expect( result ).to eq({ 'generic_defaults' => {} })
      end

      # ...explicit nil means nil...
      #
      it 'should render with correct defaults for hash keys (2)' do
        data   = { 'generic_defaults' => nil }
        result = TestHashGenericKeyPresenterWithDefaultsExceptHash.render( data )
        expect( result ).to eq({ 'generic_defaults' => nil })
      end

      # ...and when we have keys supplied, the usual default rules should apply.
      #
      it 'should render with correct defaults for hash keys (3)' do
        data   = { 'generic_defaults' => { 'hello' => nil, 'goodbye' => {}, 'another' => { 'foo' => 'present', 'bar' => 'also present' } } }
        result = TestHashGenericKeyPresenterWithDefaultsExceptHash.render( data )

        expect( result ).to eq({
          'generic_defaults' => {
            'hello'   => nil,
            'goodbye' => {                     'bar' => 'default for text field' },
            'another' => { 'foo' => 'present', 'bar' => 'also present'           }
          }
        })
      end
    end
  end

end
