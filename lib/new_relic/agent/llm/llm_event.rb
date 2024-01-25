# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

module NewRelic
  module Agent
    module Llm
      class LlmEvent
        ATTRIBUTES = %i[id ingest_source request_id span_id transaction_id trace_id response_model vendor]
        INGEST_SOURCE = 'Ruby'

        attr_accessor(*ATTRIBUTES)

        def initialize(opts = {})
          attributes.each do |attr|
            instance_variable_set(:"@#{attr}", opts[attr]) if opts.key?(attr)
          end

          @span_id = NewRelic::Agent::Tracer.current_span_id
          @transaction_id = NewRelic::Agent::Tracer.current_transaction&.guid
          @trace_id = NewRelic::Agent::Tracer.current_trace_id
          @ingest_source = INGEST_SOURCE
        end

        def event_attributes
          attributes.each_with_object({}) do |attr, hash|
            hash[attr] = instance_variable_get(:"@#{attr}")
          end
        end

        def attributes
          ATTRIBUTES
        end

        # Method for subclasses to override
        def record
        end
      end
    end
  end
end
