# frozen_string_literal: true

require_relative "test_helper"

class InputsTest < Minitest::Test
  def test_text_input_wire
    assert_equal({type: "text", text: "hello"},
      OpenAI::Codex::TextInput.new(text: "hello").to_wire)
  end

  def test_image_input_wire
    assert_equal({type: "image", url: "https://x/y.png"},
      OpenAI::Codex::ImageInput.new(url: "https://x/y.png").to_wire)
  end

  def test_local_image_input_wire
    assert_equal({type: "localImage", path: "/tmp/y.png"},
      OpenAI::Codex::LocalImageInput.new(path: "/tmp/y.png").to_wire)
  end

  def test_skill_input_wire
    assert_equal({type: "skill", name: "fmt", path: "/skills/fmt"},
      OpenAI::Codex::SkillInput.new(name: "fmt", path: "/skills/fmt").to_wire)
  end

  def test_mention_input_wire
    assert_equal({type: "mention", name: "@codex", path: "/codex"},
      OpenAI::Codex::MentionInput.new(name: "@codex", path: "/codex").to_wire)
  end

  def test_normalize_string_input_to_text_input
    normalized = OpenAI::Codex::Inputs.normalize_run_input("hi")

    assert_instance_of OpenAI::Codex::TextInput, normalized
    assert_equal "hi", normalized.text
  end

  def test_normalize_passthrough_for_non_string_input
    item = OpenAI::Codex::ImageInput.new(url: "https://x")
    assert_same item, OpenAI::Codex::Inputs.normalize_run_input(item)
  end

  def test_to_wire_input_single_item_wraps_in_array
    wire = OpenAI::Codex::Inputs.to_wire_input(OpenAI::Codex::TextInput.new(text: "hi"))

    assert_equal [{type: "text", text: "hi"}], wire
  end

  def test_to_wire_input_array_preserves_order
    wire = OpenAI::Codex::Inputs.to_wire_input([
      OpenAI::Codex::TextInput.new(text: "a"),
      OpenAI::Codex::TextInput.new(text: "b")
    ])

    assert_equal [{type: "text", text: "a"}, {type: "text", text: "b"}], wire
  end

  def test_to_wire_input_accepts_raw_hash
    wire = OpenAI::Codex::Inputs.to_wire_input({type: "text", text: "raw"})

    assert_equal [{type: "text", text: "raw"}], wire
  end

  def test_to_wire_input_rejects_unsupported_item
    assert_raises(TypeError) do
      OpenAI::Codex::Inputs.to_wire_input([Object.new])
    end
  end
end
