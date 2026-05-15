# frozen_string_literal: true

module OpenAI
  module Codex
    module Util
      module_function

      def wire_key(key)
        text = key.to_s
        return text unless text.include?("_")

        parts = text.split("_")
        ([parts.first] + parts.drop(1).map { |part| part[0].to_s.upcase + part[1..-1].to_s }).join
      end

      def ruby_key(key)
        key.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
           .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
           .tr("-", "_")
           .downcase
      end

      def deep_wire_value(value, exclude_nil: false)
        case value
        when Model
          value.to_h(exclude_nil: exclude_nil)
        when Hash
          value.each_with_object({}) do |(key, item), out|
            next if exclude_nil && item.nil?

            out[wire_key(key)] = deep_wire_value(item, exclude_nil: exclude_nil)
          end
        when Array
          value.map { |item| deep_wire_value(item, exclude_nil: exclude_nil) }
        when Symbol
          value.to_s
        else
          value
        end
      end
    end
  end
end
