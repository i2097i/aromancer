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
      :legends,
      :player # todo: not used
    ]

    attr_accessor :socket

    def self.channel_identifier
      {identifier: {channel: :PlayerChannel.to_s, id: Aromancer::Storage.get_player["id"]}.to_json}
    end

    def connect
      if !self.socket.nil? && self.socket.closed?
        disconnect
      end

      return if !self.socket.nil? ||
        Aromancer::Storage.get_player["api_key"].nil? ||
        Aromancer::Storage.get_player["active_legend_id"].nil?

      begin
        self.socket = WebSocket::Client::Simple.connect(Aromancer::Storage.get_websocket_url, {headers: Aromancer::Server.auth_header})
      rescue Socket::ResolutionError => e
        disconnect
        return
      end
      self.socket.on :message do |msg|
        payload = JSON.parse(msg.data) rescue msg.data
        if !payload.nil? &&
          !payload["identifier"].nil? &&
          !payload["message"].nil? &&
          !payload["message"]["type"].nil? &&
          TYPES.include?(payload["message"]["type"].to_sym)

          case payload["message"]["type"].to_sym
          when :arena
            legend_id = payload["message"]["id"]
            lid = Aromancer::Storage.get_player&.symbolize_keys[:active_legend_id]
            if !lid.nil? && lid == legend_id.to_i
              Aromancer::Api.load_arena
              sleep(1)
              Aromancer::Cli.instance.start_ui_thread
            end
          when :legends
            Aromancer::Api.get_legends
          when :player
          end
        end
      end

      self.socket.on :open do
        r = {"command": :subscribe.to_s}.merge(Aromancer::Websocket.channel_identifier).to_json
        Aromancer::Websocket.instance.socket.send(r)
      end

      self.socket.on :close do |e|
        Aromancer::Websocket.instance.disconnect
      end

      self.socket.on :error do |e|
        if Aromancer::Storage.get_preference(:debug)
          Aromancer::Prompt.say("#{self.class.name} socket.on :error")
          Aromancer::Prompt.say(e.inspect)
        end
        Aromancer::Websocket.instance.disconnect
      end
    end

    def disconnect
      self.socket&.close
      self.socket = nil
    end

    # todo: websockets only in-game
    # https://docs.anycable.io/misc/action_cable_protocol#perform-actions
    # def self.set_active_legend_id(id)
    #   return if self.instance.socket.nil?
    #   r = {"command": :message.to_s}.merge(Aromancer::Websocket.channel_identifier).merge({
    #     data: {action: :player.to_s, active_legend_id: id}.to_json
    #   }).to_json
    #   self.instance.socket.send(r)
    # end
  end
end
