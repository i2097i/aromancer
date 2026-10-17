# frozen_string_literal: true

=begin

  aromancer.rb

  aromancer.

  by i2097i

=end

require_relative :reiquire.to_s
Reiquire::aromancer

module Aromancer
  THROTTLE_MS = 0.1
  ERROR_EXPIRATION = 7.77.to_f
  FONT = TTY::Font.new(:standard)
  DATE_FORMAT = "%A %d %b %Y %I:%M:%S %p"
  TIME_FORMAT = "%I:%M:%S %p"

  UNICODE = {
    close: "\u2A2F",
    check: "\u2713"
  }

  class Serve
    def self.run
      unless Dir.exist?("#{Aromancer.to_s.downcase}_serve")
        system("git clone git@github.com:arowmancy/aromancer_serve.git")
      end
      FileUtils.chdir :aromancer_serve.to_s do
        system("bin/setup")
      end
    end
  end

  # instance runs on main thread
  class Cli
    include Singleton

    attr_accessor :ui_thread, :ws_thread, :busy, :ws_busy, :last_render, :error_timeout

    # user entry point
    def self.run
      # ensure preferences exist
      Aromancer::Storage.get_preference(:debug, default: false)
      Aromancer::Storage.get_preference(:force_ssl, default: true)
      Aromancer::Storage.get_preference(:hide_sentences, default: true)
      Aromancer::Storage.get_preference(:hide_stream, default: true)

      self.instance.last_render = 0
      self.instance.error_timeout = Time.now.to_i

      # load player on-start
      Aromancer::Api.set_active_legend_id(nil) unless Aromancer::Storage.get_player.nil?

      Thread.main[:route] = :authentication
      Thread.main[:menu_runners] = {}
      Thread.main[:menu_options] = {}
      Aromancer::Prompt.say(I18n.t("shared.welcome", version: Aromancer::VERSION))
      Aromancer::Prompt.say(I18n.t("shared.server_url", url: Aromancer::Storage::get_server_url))
      self.instance.start_ui_thread
      self.instance.start_ws_thread
      loop do
        begin
          self.instance.ui_thread.join
        rescue NoMethodError => e
          if Aromancer::Storage.get_preference(:debug)
            Aromancer::Prompt.say(I18n.t("shared.last_error"))
            Aromancer::Prompt.say(JSON.pretty_generate(e[:body.to_s]))
            Aromancer::Prompt.say("sleeping 5 on main thread...")
            sleep(5)
          end
          self.instance.start_ui_thread
          self.instance.start_ws_thread
          sleep(1)
        rescue Interrupt => e
          Aromancer::Prompt.say("interrupt on main thread...exiting immediately.")
          exit
        end
      end
    end

    def get_view(view_key)
      Thread.main[:menu_options][view_key.to_sym]
    end

    def start_ui_thread(force = false)
      return if (@busy || Time.now - @last_render < 2.0) && !force

      @busy = true
      self.ui_thread&.exit
      self.ui_thread&.kill
      Thread.main[:menu_runners] = {}
      Thread.main[:menu_options] = {}
      Aromancer::Prompt.instance.reload!
      self.ui_thread = Thread.new do
        loop do
          menu_options = Thread.main[:menu_options][Thread.main[:route]]
          menu_runners = Thread.main[:menu_runners][Thread.main[:route]]
          unless menu_options.nil? || menu_runners.nil?
            Aromancer::Routes.resume
            Aromancer.print_hud
            sleep(THROTTLE_MS)
            v = Aromancer::Prompt.p.select("", menu_options, show_help: :always, cycle: true, per_page: 11)
            runners = menu_runners.select{|r| r[:value] == v}
            runners = menu_runners.select{|r| r[:value].nil?} if runners.empty?

            if runners.any?
              r = runners.first
              r[:proc].call(v)
            end

          else
            Aromancer::Routes.resume
          end
          Aromancer::Cli.instance.busy = false
          Aromancer::Cli.instance.last_render = Time.now
          sleep(THROTTLE_MS)
        end
      end
    end

    def start_ws_thread
      return if @ws_busy
      @ws_busy = true
      self.ws_thread.kill unless self.ws_thread.nil?
      self.ws_thread = Thread.new do
        Aromancer::Websocket.instance.disconnect
        loop do
          player = Aromancer::Storage.get_player
          if player.nil?
            @ws_busy = true
            Aromancer::Websocket.instance.disconnect
          elsif !player["api_key"].nil?
            # attempt websocket connection
            @ws_busy = true
            Aromancer::Websocket.instance.connect
          end
          @ws_busy = false
          sleep(4)
        end
      end
    end

  end

  def self.get_font(text = :aromancer.to_s, letter_spacing = 1)
    Aromancer::FONT.write(text, letter_spacing: letter_spacing).split("\n")
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
    websocket_status = "#{Aromancer::Storage.instance.get_key(:websocket_scheme)}: #{Aromancer::Websocket.instance.socket.nil? ? UNICODE[:close] : UNICODE[:check] }"
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

    last_error = Aromancer::Storage.get_last_error
    return if last_error.nil?

    last_error = last_error.symbolize_keys
    message = last_error[:body]
    begin
      message = JSON.parse(message).symbolize_keys
      message = message[:error_message] if message.keys.include?(:error_message)
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
