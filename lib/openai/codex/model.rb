# frozen_string_literal: true

require "json"
require_relative "util"

module OpenAI
  module Codex
    class Model
      class << self
        attr_accessor :schema_name, :schema_definition

        def validate!(value)
          return true unless schema_definition

          SchemaStore.validator.validate!(value, schema_definition)
        end

        def from_wire(value, validate: true)
          new(value, validate: validate)
        end
      end

      attr_reader :raw

      def initialize(value = nil, validate: true, **kwargs)
        if !kwargs.empty?
          raise ArgumentError, "cannot combine scalar value with keyword fields" unless value.nil? || value.is_a?(Hash)

          # Treat nil kwargs as "absent" — mirrors Rust `Option<T>` +
          # `skip_serializing_if` upstream. Callers needing an explicit
          # JSON null should pass via the positional hash, not as a kwarg.
          value = (value || {}).merge(kwargs.compact)
        end

        @raw = normalize_value(value.nil? ? {} : value)
        self.class.validate!(@raw) if validate
      end

      def [](key)
        return nil unless @raw.is_a?(Hash)

        wire = Util.wire_key(key)
        value = @raw.key?(wire) ? @raw[wire] : @raw[key.to_s]
        wrap_field(wire, value)
      end

      def []=(key, value)
        raise TypeError, "cannot assign fields on scalar model" unless @raw.is_a?(Hash)

        @raw[Util.wire_key(key)] = normalize_value(value)
      end

      def fetch(key, *args)
        return self[key] if @raw.is_a?(Hash) && (@raw.key?(Util.wire_key(key)) || @raw.key?(key.to_s))
        return yield key if block_given?
        return args.first unless args.empty?

        raise KeyError, "key not found: #{key}"
      end

      def dig(*keys)
        keys.reduce(self) do |value, key|
          value.respond_to?(:[]) ? value[key] : nil
        end
      end

      def root
        return self["root"] if @raw.is_a?(Hash) && @raw.key?("root")

        self
      end

      def to_h(exclude_nil: false)
        deep_plain(@raw, exclude_nil: exclude_nil)
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      def method_missing(name, *args, &block)
        text = name.to_s
        if args.empty? && block.nil? && @raw.is_a?(Hash)
          key = text.end_with?("?") ? text[0..-2] : text
          return self[key] if @raw.key?(Util.wire_key(key)) || @raw.key?(key)
          return nil if schema_field?(Util.wire_key(key))
        end

        super
      end

      def respond_to_missing?(name, include_private = false)
        key = name.to_s.sub(/\?\z/, "")
        (@raw.is_a?(Hash) && (@raw.key?(Util.wire_key(key)) || @raw.key?(key) || schema_field?(Util.wire_key(key)))) || super
      end

      def inspect
        "#<#{self.class.name || self.class.schema_name} #{to_h.inspect}>"
      end

      private

      def normalize_value(value)
        case value
        when Model
          value.to_h
        when Hash
          value.each_with_object({}) do |(key, item), out|
            out[Util.wire_key(key)] = normalize_value(item)
          end
        when Array
          value.map { |item| normalize_value(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end

      def deep_plain(value, exclude_nil:)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), out|
            next if exclude_nil && item.nil?

            out[key] = deep_plain(item, exclude_nil: exclude_nil)
          end
        when Array
          value.map { |item| deep_plain(item, exclude_nil: exclude_nil) }
        else
          value
        end
      end

      def wrap_field(key, value)
        return wrap_value(value, nil) unless self.class.schema_definition

        schema = field_schema(key)
        wrap_value(value, schema)
      end

      def wrap_value(value, schema)
        case value
        when Hash
          klass = class_for_schema(schema)
          klass ? klass.from_wire(value, validate: false) : Model.new(value, validate: false)
        when Array
          item_schema = array_item_schema(schema)
          value.map { |item| wrap_value(item, item_schema) }
        else
          value
        end
      end

      def field_schema(key)
        schema = self.class.schema_definition
        schema = dereference(schema)
        properties = schema["properties"] if schema.is_a?(Hash)
        properties && properties[key]
      end

      def schema_field?(key)
        !!field_schema(key)
      end

      def array_item_schema(schema)
        schema = dereference(schema)
        return schema["items"] if schema.is_a?(Hash) && schema["items"]

        nil
      end

      def class_for_schema(schema)
        return nil unless schema.is_a?(Hash)

        ref = schema["$ref"]
        return SchemaStore.class_for(ref.sub(%r{\A#/definitions/}, "")) if ref

        schema = dereference(schema)
        if schema["anyOf"] || schema["oneOf"]
          Array(schema["anyOf"] || schema["oneOf"]).each do |child|
            klass = class_for_schema(child)
            return klass if klass
          end
        end

        title = schema["title"]
        title && SchemaStore.class_for(title)
      end

      def dereference(schema)
        return schema unless schema.is_a?(Hash) && schema["$ref"]

        name = schema["$ref"].sub(%r{\A#/definitions/}, "")
        SchemaStore.definitions[name] || schema
      end
    end
  end
end
