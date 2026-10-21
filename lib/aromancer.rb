# frozen_string_literal: true

=begin

  aromancer.rb

  aromancer.

  by i2097i

=end

require_relative :reiquire.to_s
Reiquire::aromancer

module Aromancer
  ERROR_EXPIRATION = 11.11.to_f
  FONT = TTY::Font.new(:standard)
  DATE_FORMAT = "%A %d %b %Y %I:%M:%S %p"
  TIME_FORMAT = "%I:%M:%S %p"

  UNICODE = {
    close: "\u2A2F",
    check: "\u2713"
  }

  def self.print_large_text(text = Aromancer.to_s.downcase, letter_spacing = 1)
    Aromancer::Prompt.say(Aromancer::FONT.write(text, letter_spacing: letter_spacing))
  end

  def self.home_directory
    "#{`echo $HOME`.strip}/.aromancer"
  end

  def self.date_display(raw)
    DateTime.parse(raw)&.strftime(Aromancer::DATE_FORMAT).downcase.gsub(" ", "_")
  end

  def self.time_display(raw)
    DateTime.parse(raw)&.strftime(Aromancer::TIME_FORMAT).downcase.gsub(" ", "_")
  end

  def self.print_hud
    print_last_error
    ws_status_symbol = (
      Aromancer::Websocket.instance.socket.nil? || Aromancer::Websocket.instance.socket.closed?
    ) ? UNICODE[:close] : UNICODE[:check]
    websocket_status = "#{Aromancer::Storage.instance.get_key(:websocket_scheme)}: #{ws_status_symbol}"
    player_status = if Aromancer::Storage.get_player.nil?
      I18n.t("routes.main_menu.not_signed_in")
    else
      I18n.t("shared.signed_in_as", as: Aromancer::Storage.get_player["alias"])
    end

    Aromancer::Prompt.say(
      [nil, :v.to_s + Aromancer::VERSION, player_status, websocket_status, nil,].join(" | ")
    )
  end

  def self.print_last_error(i18n_key = nil)
    if Time.now.to_f - Aromancer::Cli.instance.error_timeout.to_f >= Aromancer::ERROR_EXPIRATION
      Aromancer::Cli.instance.error_timeout = Time.now.to_i
      Aromancer::Storage.set_last_error(nil)
      return
    end

    last_error = Aromancer::Storage.get_last_error&.symbolize_keys

    return if last_error.nil?
    message = last_error[:body]
    begin
      message = JSON.parse(message).symbolize_keys
      message = message[:error_message] if message.keys.include?(:error_message)
    rescue TypeError => e
      message = last_error[:body]
    rescue JSON::ParserError => e
      message = last_error[:body]
    end

    if message.kind_of?(Hash)
      message = JSON.pretty_generate(message)
    elsif message.kind_of?(String)
      message = message[0..777]
    end

    Aromancer::Prompt.say(I18n.t(i18n_key || "shared.last_error", status: last_error[:status], error: message), rjust: true)
  end
end
