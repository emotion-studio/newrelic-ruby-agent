# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

module NewRelic
  module Agent
    class LogEventAttributes
      MAX_ATTRIBUTE_COUNT = 240 # limit is 255, assume we send 15 attributes by default
      ATTRIBUTE_KEY_CHARACTER_LIMIT = 255
      ATTRIBUTE_VALUE_CHARACTER_LIMIT = 4094

      attr_accessor :custom_attributes, :already_warned_custom_attribute_count_limit

      def initialize
        @custom_attributes = {}
        @already_warned_custom_attribute_count_limit = false
      end

      def add_custom_attributes(attributes)
        return if already_warned_custom_attribute_count_limit

        attributes.each do |key, value|
          next if absent?(key) || absent?(value)

          add_custom_attribute(key, value)
        end
      end

      def reset!
        @custom_attributes = {}
        @already_warned_custom_attribute_count_limit = false
      end

      private

      class TruncationError < StandardError
        attr_reader :attribute, :limit

        def initialize(attribute, limit, msg = "Can't truncate")
          @attribute = attribute
          @limit = limit
          super(msg)
        end
      end

      def absent?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def add_custom_attribute(key, value)
        if custom_attributes.size >= MAX_ATTRIBUTE_COUNT
          NewRelic::Agent.logger.warn(
            'Too many custom log attributes defined. ' \
            "Only taking the first #{MAX_ATTRIBUTE_COUNT}."
          )
          @already_warned_custom_attribute_count_limit = true
          return
        end

        @custom_attributes.merge!(truncate_attributes(key_to_string(key), value))
      end

      def key_to_string(key)
        key.is_a?(String) ? key : key.to_s
      end

      def truncate_attribute(attribute, limit)
        case attribute
        when Integer
          if attribute.digits.length > limit
            raise TruncationError.new(attribute, limit)
          end
        when Float
          if attribute.to_s.length > limit
            raise TruncationError.new(attribute, limit)
          end
        when String, Symbol
          if attribute.length > limit
            attribute = attribute.slice(0..(limit - 1))
          end
        end

        attribute
      end

      def truncate_attributes(key, value)
        key = truncate_attribute(key, ATTRIBUTE_KEY_CHARACTER_LIMIT)
        value = truncate_attribute(value, ATTRIBUTE_VALUE_CHARACTER_LIMIT)

        {key => value}
      rescue TruncationError => e
        NewRelic::Agent.logger.warn(
          "Dropping custom log attribute #{key} => #{value} \n" \
          "Length exceeds character limit of #{e.limit}. " \
          "Can't truncate: #{e.attribute}"
        )

        {}
      end
    end
  end
end
