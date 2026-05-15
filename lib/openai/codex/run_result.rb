# frozen_string_literal: true

require_relative "types"

module OpenAI
  module Codex
    RunResult = Struct.new(:final_response, :items, :usage, keyword_init: true)

    module RunResultCollector
      module_function

      def collect(stream, turn_id:)
        completed = nil
        items = []
        usage = nil

        stream.each do |event|
          payload = event.payload
          if payload.is_a?(Types::ItemCompletedNotification) && payload.turn_id == turn_id
            items << payload.item
            next
          end

          if payload.is_a?(Types::ThreadTokenUsageUpdatedNotification) && payload.turn_id == turn_id
            usage = payload.token_usage
            next
          end

          if payload.is_a?(Types::TurnCompletedNotification) && payload.turn.id == turn_id
            completed = payload
          end
        end

        raise RuntimeError, "turn completed event not received" unless completed

        raise_for_failed_turn(completed.turn)
        RunResult.new(final_response: final_response_from_items(items), items: items, usage: usage)
      end

      def raise_for_failed_turn(turn)
        return unless turn.status == "failed"

        if turn.respond_to?(:error) && turn.error && turn.error.respond_to?(:message) && turn.error.message
          raise RuntimeError, turn.error.message
        end

        raise RuntimeError, "turn failed with status #{turn.status}"
      end

      def final_response_from_items(items)
        last_unknown_phase = nil
        items.reverse_each do |item|
          root = item.respond_to?(:root) ? item.root : item
          next unless root.respond_to?(:type) && root.type == "agentMessage"

          return root.text if root.respond_to?(:phase) && root.phase == "final_answer"
          last_unknown_phase ||= root.text if !root.respond_to?(:phase) || root.phase.nil?
        end
        last_unknown_phase
      end
    end
  end
end
