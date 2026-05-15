# frozen_string_literal: true

require_relative "errors"

module OpenAI
  module Codex
    class SchemaValidator
      def initialize(definitions)
        @definitions = definitions
      end

      def validate!(value, schema, path = "$")
        return true if schema == true || schema.nil?
        raise ValidationError, "#{path} is not allowed by schema" if schema == false

        if schema["$ref"]
          return validate!(value, resolve_ref(schema["$ref"]), path)
        end

        validate_enum!(value, schema, path)
        validate_const!(value, schema, path)

        return validate_union!(value, schema["anyOf"], path, "anyOf") if schema["anyOf"]
        return validate_union!(value, schema["oneOf"], path, "oneOf") if schema["oneOf"]

        schema.fetch("allOf", []).each { |child| validate!(value, child, path) }
        validate_type!(value, schema, path) if schema.key?("type")
        true
      end

      private

      def resolve_ref(ref)
        name = ref.sub(%r{\A#/definitions/}, "")
        @definitions.fetch(name) { raise ValidationError, "unknown schema reference #{ref}" }
      end

      def validate_union!(value, variants, path, label)
        errors = []
        variants.each do |variant|
          begin
            validate!(value, variant, path)
            return true
          rescue ValidationError => error
            errors << error.message
          end
        end
        raise ValidationError, "#{path} did not match #{label}: #{errors.first}"
      end

      def validate_enum!(value, schema, path)
        return unless schema.key?("enum")
        return if schema["enum"].include?(value)

        raise ValidationError, "#{path} must be one of #{schema["enum"].inspect}, got #{value.inspect}"
      end

      def validate_const!(value, schema, path)
        return unless schema.key?("const")
        return if value == schema["const"]

        raise ValidationError, "#{path} must equal #{schema["const"].inspect}"
      end

      def validate_type!(value, schema, path)
        types = Array(schema["type"])
        return if types.any? { |type| matches_type?(value, type, schema, path) }

        raise ValidationError, "#{path} must be #{types.join(" or ")}, got #{value.class}"
      end

      def matches_type?(value, type, schema, path)
        case type
        when "null"
          value.nil?
        when "boolean"
          value == true || value == false
        when "string"
          value.is_a?(String)
        when "integer"
          value.is_a?(Integer)
        when "number"
          value.is_a?(Numeric)
        when "array"
          return false unless value.is_a?(Array)

          validate_array!(value, schema, path)
          true
        when "object"
          return false unless value.is_a?(Hash)

          validate_object!(value, schema, path)
          true
        else
          true
        end
      end

      def validate_array!(value, schema, path)
        item_schema = schema["items"]
        return if item_schema.nil? || item_schema == true

        value.each_with_index { |item, index| validate!(item, item_schema, "#{path}[#{index}]") }
      end

      def validate_object!(value, schema, path)
        schema.fetch("required", []).each do |key|
          raise ValidationError, "#{path}.#{key} is required" unless value.key?(key)
        end

        schema.fetch("properties", {}).each do |key, child_schema|
          next unless value.key?(key)

          validate!(value[key], child_schema, "#{path}.#{key}")
        end
      end
    end
  end
end
