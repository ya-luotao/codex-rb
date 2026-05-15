# frozen_string_literal: true

module OpenAI
  module Codex
    TextInput = Struct.new(:text, keyword_init: true) do
      def to_wire
        {type: "text", text: text}
      end
    end

    ImageInput = Struct.new(:url, keyword_init: true) do
      def to_wire
        {type: "image", url: url}
      end
    end

    LocalImageInput = Struct.new(:path, keyword_init: true) do
      def to_wire
        {type: "localImage", path: path}
      end
    end

    SkillInput = Struct.new(:name, :path, keyword_init: true) do
      def to_wire
        {type: "skill", name: name, path: path}
      end
    end

    MentionInput = Struct.new(:name, :path, keyword_init: true) do
      def to_wire
        {type: "mention", name: name, path: path}
      end
    end

    module Inputs
      module_function

      def normalize_run_input(input)
        input.is_a?(String) ? TextInput.new(text: input) : input
      end

      def to_wire_input(input)
        items = input.is_a?(Array) ? input : [input]
        items.map do |item|
          if item.respond_to?(:to_wire)
            item.to_wire
          elsif item.is_a?(Hash)
            item
          else
            raise TypeError, "unsupported input item: #{item.class}"
          end
        end
      end
    end
  end
end
