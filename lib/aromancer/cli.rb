# frozen_string_literal: true

=begin

  cli.rb

  aromancer cli

  by i2097i

=end

module Aromancer
  # instance runs on main thread
  class Cli
    include Singleton

    attr_accessor :ui_thread, :ws_thread, :ui_busy, :ws_busy, :last_render, :error_timeout

    THROTTLE_MS = 0.1

    # user entry point
    def self.run
      Aromancer::Websocket.instance
      Aromancer::Storage.instance

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

    def start_ui_thread(force = false)
      return if (@ui_busy || Time.now - @last_render < 2.0) && !force

      @ui_busy = true
      self.ui_thread&.exit
      self.ui_thread&.kill
      Thread.main[:menu_runners] = {}
      Thread.main[:menu_options] = {}
      Aromancer::Prompt.instance.reload!
      self.ui_thread = Thread.new do
        loop do
          menu_options = Thread.main[:menu_options][Thread.main[:route]]
          menu_runners = Thread.main[:menu_runners][Thread.main[:route]]
          unless menu_options.nil? ||
            menu_runners.nil? ||
            menu_options.empty? ||
            menu_runners.empty?

            Aromancer::Routes.resume
            sleep(THROTTLE_MS)
            Aromancer.print_hud

            v = Aromancer::Prompt.p.select("", menu_options, show_help: :always, cycle: true, per_page: 11)
            Aromancer.print_hud
            runners = menu_runners.select{|r| r[:value] == v}
            runners = menu_runners.select{|r| r[:value].nil?} if runners.empty?

            if runners.any?
              r = runners.first
              r[:proc].call(v)
            end

          else
            sleep(THROTTLE_MS)
            Aromancer::Routes.resume
          end
          Aromancer::Cli.instance.ui_busy = false
          Aromancer::Cli.instance.last_render = Time.now
          sleep(THROTTLE_MS)
        end
      end
    end

    def start_ws_thread
      return if @ws_busy
      @ws_busy = true
      self.ws_thread&.exit
      self.ws_thread&.kill
      self.ws_thread = Thread.new do
        Aromancer::Websocket.instance.disconnect
        loop do
          player = Aromancer::Storage.get_player
          if player.nil? ||
            player["active_legend_id"].nil?
            @ws_busy = true
            Aromancer::Websocket.instance.disconnect
          elsif !player["api_key"].nil? &&
            !player["active_legend_id"].nil? &&
            (Aromancer::Websocket.instance.socket.nil? || Aromancer::Websocket.instance.socket.closed?)
            # attempt websocket connection
            @ws_busy = true
            Aromancer::Websocket.instance.connect
            if Aromancer::Storage.get_arena.nil?
              Aromancer::Api.load_arena
              sleep(1)
              Aromancer::Cli.instance.start_ui_thread(true)
            end
          end
          @ws_busy = false
          sleep(1)
        end
      end
    end
  end
end
