# frozen_string_literal: true

=begin

  aromancer.rb

  aromancer.

  by i2097i

=end

require_relative :reiquire.to_s
Reiquire::aromancer

module Aromancer
  THROTTLE_MS = 0.4
  FONT = TTY::Font.new(:standard)

  # instance runs on main thread
  class Cli
    include Singleton

    attr_accessor :ui_thread, :ws_thread, :busy, :last_render

    # user entry point
    def self.run
      Thread.main[:route] = :authentication
      self.instance.last_render = Time.now
      Aromancer::Prompt.say(I18n.t("shared.welcome", version: Aromancer::VERSION))
      Aromancer::Prompt.say(I18n.t("shared.server_url", url: Aromancer::Storage::get_server_url))
      self.instance.start_ui_thread
      self.instance.start_ws_thread
      loop do
        begin
          self.instance.ui_thread.join
        rescue NoMethodError => e
          self.instance.start_ui_thread
          sleep(1)
        rescue Interrupt => e
          exit
        end
      end
    end

    def start_ui_thread
      if @busy || Time.now - @last_render < 2
        return
      end
      @busy = true
      self.ui_thread&.exit
      self.ui_thread&.kill
      Thread.main[:input_controls] = nil
      Aromancer::Prompt.instance.reload!
      self.ui_thread = Thread.new do
        loop do
          ic = Thread.main[:input_controls]
          unless ic.nil?
            Aromancer::Routes.resume
            sleep(THROTTLE_MS)
            v = Aromancer::Prompt.p.select("", ic[:choices], show_help: :always, cycle: true, per_page: 11)
            runners = ic[:runners].select{|r| r[:value] == v}
            runners = ic[:runners].select{|r| r[:value].nil?} if runners.empty?

            if runners.any?
              r = runners.first
              r[:proc].call(v)
            else
              exit
            end
          else
            Aromancer::Routes.resume
          end
          Aromancer::Cli.instance.busy = false
          Aromancer::Cli.instance.last_render = Time.now
          # sleep(THROTTLE_MS)
        end
      end
    end

    def start_ws_thread
      self.ws_thread.kill unless self.ws_thread.nil?
      self.ws_thread = Thread.new do
        loop do
          player = Aromancer::Storage.get_player
          if player.nil?
            Aromancer::Websocket.instance.disconnect
          elsif !player["api_key"].nil?
            # attempt websocket connection
            # puts :ws_thread
            Aromancer::Websocket.instance.connect
          end

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

  def self.print_last_error(i18n_key = nil)
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
    Aromancer::Prompt.say(I18n.t(i18n_key, status: last_error[:status], error: message))
  end
end
