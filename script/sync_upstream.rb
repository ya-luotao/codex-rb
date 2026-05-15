# frozen_string_literal: true

require "fileutils"
require "json"

ROOT = File.expand_path("..", __dir__)
UPSTREAM = File.expand_path("../codex", ROOT)
SCHEMA_ROOT = File.join(UPSTREAM, "codex-rs", "app-server-protocol", "schema")
COMMON_RS = File.join(UPSTREAM, "codex-rs", "app-server-protocol", "src", "protocol", "common.rs")

def read(path)
  File.read(path)
rescue Errno::ENOENT
  abort "missing upstream file: #{path}"
end

def camelize_variant(name)
  name.sub(/\A[A-Z]/) { |char| char.downcase }
end

def type_name(raw)
  return nil if raw.nil?

  text = raw.gsub(/\s+/, " ").strip
  return nil if text.include?("Option<()>") || text == "undefined"

  text = text.split("::").last
  text.gsub(/[^A-Za-z0-9_].*\z/, "")
end

def parse_client_methods(source)
  macro_start = source.index("client_request_definitions!")
  macro_end = source.index("\n}\n\n/// Generates an `enum ServerRequest`", macro_start)
  body = source[macro_start...macro_end]
  methods = []

  pattern = /
    (?:\#\[experimental\("(?<experimental>[^"]+)"\)\]\s*)?
    (?<variant>[A-Za-z0-9_]+)
    (?:\s*=>\s*"(?<wire>[^"]+)")?
    \s*\{
      \s*params:\s*(?<params>.*?)
      \s*serialization:\s*.*?
      \s*(?:manual_payload_conversion:\s*manual,\s*)?
      response:\s*(?<response>[^,\n]+),
    \s*\}
  /mx

  body.scan(pattern) do
    match = Regexp.last_match
    variant = match[:variant]
    methods << {
      "variant" => variant,
      "method" => match[:wire] || camelize_variant(variant),
      "params" => type_name(match[:params]),
      "response" => type_name(match[:response]),
      "experimental" => !match[:experimental].nil?
    }
  end

  methods
end

def parse_notifications(source)
  source.scan(/\{ "method": "([^"]+)", "params": ([A-Za-z0-9_]+) \}/).map do |method, params|
    {"method" => method, "params" => params}
  end
end

def write_json(path, value)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(value) + "\n")
end

data_dir = File.join(ROOT, "data")
FileUtils.rm_rf(File.join(data_dir, "schemas"))
FileUtils.mkdir_p(File.join(data_dir, "schemas", "json"))
FileUtils.cp(File.join(SCHEMA_ROOT, "json", "codex_app_server_protocol.v2.schemas.json"),
  File.join(data_dir, "schemas", "json", "codex_app_server_protocol.v2.schemas.json"))
Dir[File.join(SCHEMA_ROOT, "json", "*.json")].each do |path|
  FileUtils.cp(path, File.join(data_dir, "schemas", "json", File.basename(path)))
end
FileUtils.cp_r(File.join(SCHEMA_ROOT, "json", "v2"),
  File.join(data_dir, "schemas", "json", "v2"))

write_json(File.join(data_dir, "protocol_methods.json"), parse_client_methods(read(COMMON_RS)))
write_json(File.join(data_dir, "protocol_notifications.json"),
  parse_notifications(read(File.join(SCHEMA_ROOT, "typescript", "ServerNotification.ts"))))

puts "synced Codex app-server protocol artifacts into #{data_dir}"
