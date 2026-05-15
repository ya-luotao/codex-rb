# frozen_string_literal: true

require "json"
require_relative "schema_validator"

module OpenAI
  module Codex
    module SchemaStore
      DATA_DIR = File.expand_path("../../../data", __dir__)
      AGGREGATE_SCHEMA = File.join(DATA_DIR, "schemas", "json", "codex_app_server_protocol.v2.schemas.json")
      METHODS_PATH = File.join(DATA_DIR, "protocol_methods.json")
      NOTIFICATIONS_PATH = File.join(DATA_DIR, "protocol_notifications.json")

      module_function

      def aggregate_schema
        @aggregate_schema ||= JSON.parse(File.read(AGGREGATE_SCHEMA))
      end

      def definitions
        @definitions ||= begin
          merged = aggregate_schema.fetch("definitions").dup
          schema_files.each do |path|
            schema = JSON.parse(File.read(path))
            schema.fetch("definitions", {}).each { |name, definition| merged[name] ||= definition }
            title = schema["title"] || File.basename(path, ".json")
            merged[title] ||= schema if title
          end
          merged
        end
      end

      def validator
        @validator ||= SchemaValidator.new(definitions)
      end

      def methods
        @methods ||= JSON.parse(File.read(METHODS_PATH))
      end

      def notifications
        @notifications ||= JSON.parse(File.read(NOTIFICATIONS_PATH))
      end

      def schema_files
        @schema_files ||= Dir[File.join(DATA_DIR, "schemas", "json", "**", "*.json")].sort
      end

      def method_info(method)
        method_map[method]
      end

      def response_type_for(method)
        info = method_info(method)
        info && info["response"]
      end

      def params_type_for(method)
        info = method_info(method)
        info && info["params"]
      end

      def notification_type_for(method)
        notification_map[method]
      end

      def class_for(name)
        return nil unless defined?(Types)
        return nil unless Types.const_defined?(name, false)

        Types.const_get(name, false)
      end

      def define_types!(namespace, base_class)
        return if defined?(@defined_types) && @defined_types

        definitions.each do |name, schema|
          next unless name =~ /\A[A-Z][A-Za-z0-9_]*\z/

          klass = Class.new(base_class)
          klass.schema_name = name
          klass.schema_definition = schema
          define_enum_constants(klass, schema)
          namespace.const_set(name, klass) unless namespace.const_defined?(name, false)
        end

        title = aggregate_schema["title"]
        if title && !namespace.const_defined?(title, false)
          klass = Class.new(base_class)
          klass.schema_name = title
          klass.schema_definition = aggregate_schema
          namespace.const_set(title, klass)
        end

        (methods.flat_map { |info| [info["params"], info["response"]] } +
          notifications.map { |info| info["params"] }).compact.uniq.each do |name|
          next unless name =~ /\A[A-Z][A-Za-z0-9_]*\z/
          next if namespace.const_defined?(name, false)

          klass = Class.new(base_class)
          klass.schema_name = name
          klass.schema_definition = nil
          namespace.const_set(name, klass)
        end

        @defined_types = true
      end

      def method_map
        @method_map ||= methods.each_with_object({}) { |info, out| out[info["method"]] = info }
      end

      def notification_map
        @notification_map ||= notifications.each_with_object({}) do |info, out|
          out[info["method"]] = info["params"]
        end
      end

      def define_enum_constants(klass, schema)
        enum_values(schema).each do |value|
          const = enum_constant_name(value)
          klass.const_set(const, value) unless klass.const_defined?(const, false)
        end
      end

      def enum_values(schema)
        values = []
        values.concat(schema["enum"]) if schema["enum"].is_a?(Array)
        schema.fetch("anyOf", []).each { |child| values.concat(enum_values(child)) }
        schema.fetch("oneOf", []).each { |child| values.concat(enum_values(child)) }
        values.compact.uniq
      end

      def enum_constant_name(value)
        name = value.to_s.gsub(/[^A-Za-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").upcase
        name = "VALUE" if name.empty?
        name = "VALUE_#{name}" if name =~ /\A\d/
        name
      end
    end
  end
end
