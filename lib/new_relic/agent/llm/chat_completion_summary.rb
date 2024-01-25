# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

require_relative 'response_headers'

module NewRelic
  module Agent
    module Llm
      class ChatCompletionSummary < ChatCompletion
        include ResponseHeaders

        ATTRIBUTES = %i[request_model response_organization response_usage_total_tokens
          response_usage_prompt_tokens response_usage_completion_tokens duration]
        EVENT_NAME = 'LlmChatCompletionSummary'

        attr_accessor(*ATTRIBUTES)

        def attributes
          LlmEvent::ATTRIBUTES + ChatCompletion::ATTRIBUTES + ResponseHeaders::ATTRIBUTES + ATTRIBUTES
        end

        def record
          NewRelic::Agent.record_custom_event(EVENT_NAME, event_attributes)
        end
      end
    end
  end
end
