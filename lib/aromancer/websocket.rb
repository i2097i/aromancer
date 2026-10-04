# frozen_string_literal: true

=begin

  websocket.rb

  websocket client.

  by i2097i

=end

module Aromancer
  class Websocket
    include Singleton

    TYPES = [
      :arena,
      :player
    ]

    attr_accessor :socket

    def connect(api_key)
      return unless self.socket.nil?
      self.socket = WebSocket::Client::Simple.connect("#{Aromancer::Storage.get_websocket_url}?api_key=#{api_key}")
      self.socket.on :message do |msg|
        payload = JSON.parse(msg.data) rescue msg.data
        if !payload.nil? &&
          !payload["identifier"].nil? &&
          !payload["message"].nil? &&
          !payload["message"]["type"].nil? &&
          TYPES.include?(payload["message"]["type"].to_sym)

          legend_id = payload["message"]["id"]
          lid = Aromancer::Storage.get_player&.symbolize_keys[:active_legend_id]
          if !lid.nil? && lid == legend_id.to_i
            Aromancer::Cli.instance.start_ui_thread
          end
        end
      end

      self.socket.on :open do
        r = {
          command: "subscribe",
          identifier: {channel: "PlayerChannel", api_key: api_key}.to_json
        }.to_json
        Aromancer::Websocket.instance.socket.send(r)
      end

      self.socket.on :close do |e|
        Aromancer::Websocket.instance.disconnect
      end

      self.socket.on :error do |e|
        puts e.inspect
        Aromancer::Websocket.instance.disconnect
      end
    end

    def disconnect
      self.socket = nil unless self.socket.nil?
    end
  end
end
