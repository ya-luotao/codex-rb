# frozen_string_literal: true

require_relative "types"

module OpenAI
  module Codex
    Notification = Struct.new(:method, :payload, keyword_init: true)

    class UnknownNotification
      attr_reader :params

      def initialize(params = {})
        @params = params.is_a?(Hash) ? params : {}
      end
    end

    module NotificationRegistry
      module_function

      def coerce(method, params)
        type_name = SchemaStore.notification_type_for(method)
        klass = type_name && SchemaStore.class_for(type_name)
        payload =
          if klass
            begin
              klass.from_wire(params.is_a?(Hash) ? params : {}, validate: true)
            rescue ValidationError
              UnknownNotification.new(params)
            end
          else
            UnknownNotification.new(params)
          end

        Notification.new(method: method, payload: payload)
      end

      def turn_id(notification_or_payload)
        payload = notification_or_payload.respond_to?(:payload) ? notification_or_payload.payload : notification_or_payload

        if payload.is_a?(UnknownNotification)
          raw = payload.params
          direct = raw["turnId"] || raw[:turnId]
          return direct if direct.is_a?(String)

          nested = raw["turn"] || raw[:turn]
          if nested.is_a?(Hash)
            nested_id = nested["id"] || nested[:id]
            return nested_id if nested_id.is_a?(String)
          end
          return nil
        end

        if payload.respond_to?(:turn_id)
          direct = payload.turn_id
          return direct if direct.is_a?(String)
        end

        if payload.respond_to?(:turn)
          turn = payload.turn
          return turn.id if turn.respond_to?(:id) && turn.id.is_a?(String)
        end

        nil
      end
    end
  end
end
