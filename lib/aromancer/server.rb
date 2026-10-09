# frozen_string_literal: true

=begin

  server.rb

  aromancer server interface.

  by i2097i

=end

module Aromancer
  class Server
    include Singleton

    HEADERS = { "Content-Type": "application/json" }

    class InternalError
      attr_accessor :status, :body

      def initialize(status: -1, body: {})
        @status = status
        @body = body
        Aromancer::Storage.instance.clear_cache!
      end

      def self.build(e)
        InternalError.new(
          status: -1,
          body: {error_message: e.inspect.to_s}.to_json
        )
      end
    end

    def self.auth_header
      {"Authorization": "Bearer #{Aromancer::Storage.get_player["api_key"]}"}
    end

    def self.sign_in(email_address, password)
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
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
          url: Aromancer::Storage.get_server_url,
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
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
        ).delete("/session")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.create_legend(params)
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
          params: params
        ).post("/legends")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_legends
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
        ).get("/legends")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.update_player(params)
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
          params: params
        ).put("/players/#{Aromancer::Storage.get_player["id"]}")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_arena
      legend_id = Aromancer::Storage.get_player["active_legend_id"]

      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
        ).get("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_stream
      legend_id = Aromancer::Storage.get_player["active_legend_id"]

      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
        ).get("/legends/#{legend_id}/stream")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.get_word_possibilities(selected_word_id)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
        ).get("/legends/#{legend_id}/words/#{selected_word_id}/possibilities")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.create_turn(params)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
          params: params
        ).post("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end

    def self.update_turn(params)
      legend_id = Aromancer::Storage.get_player["active_legend_id"]
      begin
        Faraday.new(
          url: Aromancer::Storage.get_server_url,
          headers: HEADERS.merge(auth_header),
          params: params
        ).put("/legends/#{legend_id}/arena")
      rescue StandardError => e
        InternalError.build(e)
      end
    end
  end
end
