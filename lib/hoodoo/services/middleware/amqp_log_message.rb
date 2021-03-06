########################################################################
# File::    amqp_log_message.rb
# (C)::     Loyalty New Zealand 2014
#
# Purpose:: Structured logging onto an AMQP-based queue, via the
#           AlchemyAMQ gem. Optional; class is defined only if the
#           supporting AlchemyAMQ gem's classes are defined.
#
#           The middleware uses this to put log and error messages
#           on the queue. Interested services use this to read such
#           messages from the queue.
# ----------------------------------------------------------------------
#           20-Nov-2014 (ADH): Created.
########################################################################

# TODO: See spec/alchemy/alchemy-amq.rb. Remove this once 'real' Alchemy
#       is opened.
#
$LOAD_PATH.unshift File.join( File.dirname( __FILE__ ), 'alchemy' )

module Hoodoo; module Services
  class Middleware

    begin
      require 'alchemy-amq' # Optional

      # For AlchemyAMQ gem users, the AMQPLogMessage class provides an
      # AlchemyAMQ::Message subclass used for sending structured log data to
      # the queue. Hoodoo::Logger uses this.
      #
      # See the AlchemyAMQ gem for more details.
      #
      class AMQPLogMessage < ::AlchemyAMQ::Message

        # The named "type" of this message, to be registered with AlchemyAMQ.
        #
        TYPE = 'hoodoo_service_middleware_amqp_log_message'

        # The Time +strftime+ formatter used for string conversions in this
        # class.
        #
        TIME_FORMATTER = '%Y-%m-%d %H:%M:%S.%12N %Z'

        # This line of code registers wth AlchemyAMQ, but also makes RDoc
        # screw up. RDoc decides that we have a new module,
        # Hoodoo::Services::Middleware::AMQPLogMessage::AlchemyAMQ. Very
        # strange...
        #
        ::AlchemyAMQ::Message.register_type( TYPE, self )

        # ...so do _this_ purely so that we can get 100% real documentation
        # coverage without it being clouded by RDoc's hiccups.

        # This documentation exists purely to work around an RDoc hiccup where
        # it thinks such a module exists.
        #
        # See file "services/middleware/amqp_log_message.rb" for details.
        #
        module AlchemyAMQ
        end

        # A UUID to assign to this log message. See Hoodoo::UUID::generate.
        #
        attr_accessor :id

        # Logging level. See Hoodoo::Logger.
        #
        attr_accessor :level

        # Logging component. See Hoodoo::Logger.
        #
        attr_accessor :component

        # Component log code. See Hoodoo::Logger.
        #
        attr_accessor :code

        # The time at which this log message is being reported to the Logger
        # instance. This is a formatted *String* to high accuracy. See also
        # #reported_at=.
        #
        attr_reader :reported_at

        # Set the time read back by #reported_at using a Time instance. This
        # is formatted internally as a String via TIME_FORMATTER and reported
        # as such in subsequent calls to #reported_at.
        #
        # Conversion from Time to String is done here, rather than by the
        # caller setting this instance's variables, so that we can internally
        # enforce the accuracy required for this field.
        #
        # +time+:: The Time instance to set (and process into a string
        #          internally via TIME_FORMATTER), *or* a String instance
        #          already so formatted, *or* +nil+ to clear the value.
        #
        def reported_at=( time )
          if time.is_a?( String )
            @reported_at = time
          elsif time.is_a?( Time )
            @reported_at = time.strftime( TIME_FORMATTER )
          else
            @reported_at = nil
          end
        end

        # Log payload. See Hoodoo::Logger.
        #
        attr_accessor :data

        # Optional calling Caller ID, via session data inside the payload - see
        # Hoodoo::Logger.
        #
        attr_accessor :caller_id

        # Optional interaction UUID, via session data inside the payload - see
        # Hoodoo::Logger.
        #
        attr_accessor :interaction_id

        # Optional hash of identity properties from the session data inside the
        # payload - see Hoodoo::Logger.
        #
        attr_accessor :identity

        # Create an instance with options keyed on the attributes defined for
        # the class.
        #
        def initialize(options = {})
          update( options ) # Should be called before 'super'
          super( options )

          @type = AMQPLogMessage::TYPE
        end

        # Seralize this instance. See the AlchemyAMQ gem and
        # AlchemyAMQ::Message#serialize.
        #
        def serialize
          @content = {
            :id             => @id,
            :level          => @level,
            :component      => @component,
            :code           => @code,
            :reported_at    => @reported_at,

            :data           => @data,

            :interaction_id => @interaction_id,
            :caller_id      => @caller_id,
            :identity       => @identity
          }

          super
        end

        # Unpack a serialized representation into this instance. See the
        # AlchemyAMQ gem and AlchemyAMQ::Message#deserialize.
        #
        def deserialize
          super
          update( @content )
        end

        # Set public attribute values according to an options hash keyed on
        # the attributes defined for the class.
        #
        def update( options )
          self.id             = options[ :id             ]
          self.level          = options[ :level          ]
          self.component      = options[ :component      ]
          self.code           = options[ :code           ]
          self.reported_at    = options[ :reported_at    ]

          self.data           = options[ :data           ]

          self.interaction_id = options[ :interaction_id ]
          self.caller_id      = options[ :caller_id      ]
          self.identity       = options[ :identity       ]
        end
      end

    rescue LoadError # Optional file 'alchemy-amq' is absent
    end

  end
end; end
