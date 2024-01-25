# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

# require_relative '../llm_event'

module NewRelic
  module Agent
    module Llm
      class ChatCompletion < LlmEvent
        ATTRIBUTES = %i[api_key_last_four_digits conversation_id request_max_tokens response_number_of_messages]

        attr_accessor(*ATTRIBUTES)

        def attributes
          ATTRIBUTES + LlmEvent::ATTRIBUTES
        end

        # Method for subclasses to override
        def record
        end
      end
    end
  end
end
