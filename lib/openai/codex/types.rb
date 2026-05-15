# frozen_string_literal: true

require_relative "schema_store"
require_relative "model"

module OpenAI
  module Codex
    module Types
    end

    SchemaStore.define_types!(Types, Model)

    unless Types.const_defined?(:ServerInfo, false)
      Types.const_set(:ServerInfo, Class.new(Model))
    end
    Types::ServerInfo.schema_name = "ServerInfo"
    Types::ServerInfo.schema_definition = {
      "type" => "object",
      "properties" => {
        "name" => { "type" => ["string", "null"] },
        "version" => { "type" => ["string", "null"] }
      }
    }

    Types::InitializeResponse.schema_definition = {
      "type" => "object",
      "properties" => {
        "serverInfo" => {
          "anyOf" => [
            {
              "type" => "object",
              "properties" => {
                "name" => { "type" => ["string", "null"] },
                "version" => { "type" => ["string", "null"] }
              }
            },
            { "type" => "null" }
          ]
        },
        "userAgent" => { "type" => ["string", "null"] },
        "platformFamily" => { "type" => ["string", "null"] },
        "platformOs" => { "type" => ["string", "null"] },
        "codexHome" => { "type" => ["string", "null"] }
      }
    }
  end
end
