# frozen_string_literal: true

=begin

  server.rb

  aromancer server interface.

  by i2097i

=end

module Aromancer
  class Server
    include Singleton
    SERVER_HOST_FILE = ".aromancer_server_host"
    SERVER_URL = File.exist?(SERVER_HOST_FILE) ? File.read(SERVER_HOST_FILE).gsub("\n", "") : "http://localhost:3000"
    HEADERS = { "Content-Type": "application/json" }

    class InternalError
      attr_accessor :status, :body

      def initialize(status: -1, body: {})
        @status = status
        @body = body
      end

      def self.build(e)
        InternalError.new(
          status: -1,
          body: {error_message: e.message[0..78]}.to_json
        )
      end
    end

    def self.api_key_param
      {
        api_key: Aromancer::Storage.get_player["api_key"]
      }
    end

    def self.sign_in(email_address, password)
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: {
            email_address: email_address,
            password: password
          }
        ).post("/session")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.sign_up(email_address, password, password_confirmation)
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: {
            user: {
              email_address: email_address,
              password: password,
              password_confirmation: password_confirmation
            }
          }
        ).post("/users")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.sign_out
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: api_key_param
        ).delete("/session")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.create_legend(params)
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: params.merge(api_key_param)
        ).post("/legends")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_legends
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: api_key_param
        ).get("/legends")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.update_player(params)
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: params.merge(api_key_param)
        ).put("/players/#{Aromancer::Storage.get_player["id"]}")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_arena
      legend_id = Aromancer::Storage.get_player["active_legend_id"]

      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: api_key_param
        ).get("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_stream
      legend_id = Aromancer::Storage.get_player["active_legend_id"]

      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: api_key_param
        ).get("/legends/#{legend_id}/stream")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_word_possibilities(selected_word_id)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: api_key_param
        ).get("/legends/#{legend_id}/words/#{selected_word_id}/possibilities")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.create_turn(params)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: params.merge(api_key_param)
        ).post("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.update_turn(params)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: SERVER_URL,
          headers: HEADERS,
          params: params.merge(api_key_param)
        ).put("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end
  end
end
