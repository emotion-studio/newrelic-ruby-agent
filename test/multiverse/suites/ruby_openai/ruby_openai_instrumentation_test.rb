# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

require_relative 'openai_helpers'

class RubyOpenAIInstrumentationTest < Minitest::Test
  include OpenAIHelpers

  def setup
    @aggregator = NewRelic::Agent.agent.custom_event_aggregator
  end

  def teardown
    NewRelic::Agent.drop_buffered_data
  end

  def test_instrumentation_doesnt_record_anything_with_other_paths_that_use_json_post
    in_transaction do
      stub_post_request do
        connection_client.json_post(path: '/edits', parameters: edits_params)
      end
    end

    refute_metrics_recorded(["Supportability/Ruby/ML/OpenAI/#{::OpenAI::VERSION}"])
  end

  def test_openai_metric_recorded_for_chat_completions_every_time
    in_transaction do
      stub_post_request do
        client.chat(parameters: chat_params)
        client.chat(parameters: chat_params)
      end
    end

    assert_metrics_recorded({"Supportability/Ruby/ML/OpenAI/#{::OpenAI::VERSION}" => {call_count: 2}})
  end

  def test_openai_chat_completion_segment_name
    txn = in_transaction do
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end

    refute_nil chat_completion_segment(txn)
  end

  def test_summary_event_has_duration_of_segment
    txn = in_transaction do
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end

    segment = chat_completion_segment(txn)

    assert_equal segment.duration, segment.llm_event.duration
  end

  def test_chat_completion_records_summary_event
    in_transaction do
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end
    _, events = @aggregator.harvest!
    summary_events = events.filter { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionSummary::EVENT_NAME }

    assert_equal 1, summary_events.length

    # TODO: Write tests that validate the event has the correct attributes
  end

  def test_chat_completion_records_message_events
    in_transaction do
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end
    _, events = @aggregator.harvest!
    message_events = events.filter { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionMessage::EVENT_NAME }

    assert_equal 5, message_events.length
    # TODO: Write tests that validate the event has the correct attributes
  end

  def test_segment_error_captured_if_raised
    txn = raise_segment_error do
      client.chat(parameters: chat_params)
    end

    assert_segment_noticed_error(txn, /Llm.*OpenAI\/.*/, RuntimeError.name, /deception/i)
  end

  def test_segment_summary_event_sets_error_true_if_raised
    txn = raise_segment_error do
      client.chat(parameters: chat_params)
    end

    segment = chat_completion_segment(txn)

    refute_nil segment.llm_event
    assert_truthy segment.llm_event.error
  end

  def test_chat_completion_returns_chat_completion_body
    result = nil

    in_transaction do
      stub_post_request do
        result = client.chat(parameters: chat_params)
      end
    end

    if Gem::Version.new(::OpenAI::VERSION) >= Gem::Version.new('6.0.0')
      assert_equal ChatResponse.new.body, result
    else
      assert_equal ChatResponse.new.body(return_value: true), result
    end
  end

  def test_set_llm_agent_attribute_on_chat_transaction
    in_transaction do |txn|
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end

    assert_truthy harvest_transaction_events![1][0][2][:llm]
  end

  def test_conversation_id_added_to_summary_events
    conversation_id = '12345'
    in_transaction do
      NewRelic::Agent.add_custom_attributes({'llm.conversation_id' => conversation_id})
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end

    _, events = @aggregator.harvest!
    summary_event = events.find { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionSummary::EVENT_NAME }

    assert_equal conversation_id, summary_event[1]['conversation_id']
  end

  def test_conversation_id_added_to_message_events
    conversation_id = '12345'

    in_transaction do
      NewRelic::Agent.add_custom_attributes({'llm.conversation_id' => conversation_id})
      stub_post_request do
        client.chat(parameters: chat_params)
      end
    end

    _, events = @aggregator.harvest!
    message_events = events.filter { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionMessage::EVENT_NAME }

    message_events.each do |event|
      assert_equal conversation_id, event[1]['conversation_id']
    end
  end

  # Flaky test. Depending on the order the tests are run, the
  # conversation_id attribute from previous tests may be included on the
  # events generated here.
  # def test_conversation_id_not_on_event_if_not_present_in_custom_attributes
  #   in_transaction do |txn|
  #     NewRelic::Agent.add_custom_attributes({unique: 'attr'})
  #     stub_post_request do
  #       client.chat(parameters: chat_params)
  #     end
  #   end

  #   _, events = @aggregator.harvest!

  #   events.each do |event|
  #     refute event[1]['conversation_id']
  #   end
  # end

  def test_openai_embedding_segment_name
    txn = in_transaction do
      stub_embeddings_post_request do
        client.embeddings(parameters: embeddings_params)
      end
    end

    refute_nil embedding_segment(txn)
  end

  def test_embedding_has_duration_of_segment
    txn = in_transaction do
      stub_embeddings_post_request do
        client.embeddings(parameters: embeddings_params)
      end
    end

    segment = embedding_segment(txn)

    assert_equal segment.duration, segment.llm_event.duration
  end

  def test_openai_metric_recorded_for_embeddings_every_time
    in_transaction do
      stub_embeddings_post_request do
        client.embeddings(parameters: embeddings_params)
        client.embeddings(parameters: embeddings_params)
      end
    end

    assert_metrics_recorded({"Supportability/Ruby/ML/OpenAI/#{::OpenAI::VERSION}" => {call_count: 2}})
  end

  def test_embedding_event_sets_error_true_if_raised
    txn = raise_segment_error do
      client.embeddings(parameters: embeddings_params)
    end
    segment = embedding_segment(txn)

    refute_nil segment.llm_event
    assert_truthy segment.llm_event.error
  end

  def test_set_llm_agent_attribute_on_embedding_transaction
    in_transaction do |txn|
      stub_embeddings_post_request do
        client.embeddings(parameters: embeddings_params)
      end
    end

    assert_truthy harvest_transaction_events![1][0][2][:llm]
  end

  def test_embeddings_drop_input_when_record_content_disabled
    with_config(:'ai_monitoring.record_content.enabled' => false) do
      in_transaction do
        stub_embeddings_post_request do
          client.embeddings(parameters: embeddings_params)
        end
      end
    end
    _, events = @aggregator.harvest!

    refute events[0][1]['input']
  end

  def test_messages_drop_content_when_record_content_disabled
    with_config(:'ai_monitoring.record_content.enabled' => false) do
      in_transaction do
        stub_post_request do
          client.chat(parameters: chat_params)
        end
      end
      _, events = @aggregator.harvest!
      message_events = events.filter { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionMessage::EVENT_NAME }

      message_events.each do |event|
        refute message_events[0][1]['content']
      end
    end
  end

  def test_embeddings_include_input_when_record_content_enabled
    with_config(:'ai_monitoring.record_content.enabled' => true) do
      in_transaction do
        stub_embeddings_post_request do
          client.embeddings(parameters: embeddings_params)
        end
      end
    end
    _, events = @aggregator.harvest!

    assert_truthy events[0][1]['input']
  end

  def test_messages_include_content_when_record_content_enabled
    with_config(:'ai_monitoring.record_content.enabled' => true) do
      in_transaction do
        stub_post_request do
          client.chat(parameters: chat_params)
        end
      end
      _, events = @aggregator.harvest!
      message_events = events.filter { |event| event[0]['type'] == NewRelic::Agent::Llm::ChatCompletionMessage::EVENT_NAME }

      message_events.each do |event|
        assert_truthy message_events[0][1]['content']
      end
    end
  end
end
