# frozen_string_literal: true

require_relative "test_helper"

class FutureTest < Minitest::Test
  def test_future_resolves_with_block_value
    future = OpenAI::Codex::Future.run { 1 + 1 }

    assert_equal 2, future.value!
    assert future.completed?
  end

  def test_future_propagates_exception_to_caller
    future = OpenAI::Codex::Future.run { raise ArgumentError, "boom" }

    assert_raises(ArgumentError) { future.value! }
    assert future.completed?
  end

  def test_future_value_raises_timeout_when_block_pending
    future = OpenAI::Codex::Future.run {
      sleep 0.5
      1
    }

    assert_raises(OpenAI::Codex::Future::TimeoutError) { future.value!(0.01) }
  end

  def test_future_value_supports_repeated_calls
    future = OpenAI::Codex::Future.run { :value }

    assert_equal :value, future.value!
    assert_equal :value, future.value!
  end

  def test_future_requires_a_block
    assert_raises(ArgumentError) { OpenAI::Codex::Future.new }
  end
end
