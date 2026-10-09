# frozen_string_literal: true

=begin

  routes.rb

  view routing and configuration.

  by i2097i

=end

module Aromancer
  class Routes

    def self.resume
      return main_menu if Aromancer::Storage.get_signed_out_flag

      unless Thread.main[:route].nil?
        begin
          Thread.main[:route_params] ||= []
          if Thread.main[:route_params].any?
            self.send(Thread.main[:route], *Thread.main[:route_params])
            Thread.main[:route_params] = []
          else
            self.send(Thread.main[:route])
          end
        rescue ArgumentError => e
          authentication
        end
        return
      end

      legend_menu if !active_legend.nil? &&
        (Aromancer::Storage.get_player && Aromancer::Storage.get_player&.symbolize_keys[:active_legend_id])
      authentication
    end

    def self.cls
      puts TTY::Screen.width
      print TTY::Cursor.move(0, 0)
      print TTY::Cursor.clear_screen
      print TTY::Cursor.clear_screen_up
    end

    def self.active_legend
      (
        Aromancer::Storage.get_legends&.select{|l| l["id"] == (Aromancer::Storage.get_player || {})["active_legend_id"]} || []
      ).first
    end

    def self.arena_data
      arena = Aromancer::Storage.get_arena
      if arena.nil?
        Aromancer::Api.load_arena
        sleep(1)
      end

      if arena.nil?
        Aromancer.print_last_error("routes.legend.arena_failed")
        Aromancer::Api.set_active_legend_id(nil)
        Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
        main_menu
      else
        arena
      end
    end

    def self.authentication
      if Aromancer::Storage.get_player
        Aromancer::Storage.set_signed_out_flag(false)
        return main_menu
      end

      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :authentication)) if Aromancer::Storage.get_preference(:debug)

      Thread.main[:menu_options][__method__.to_sym] ||= [
        {name: I18n.t("routes.authentication.sign_in"), value: :in},
        {name: I18n.t("routes.authentication.sign_up"), value: :up},
        {name: I18n.t("routes.main_menu.configure"), value: :configure},
        {name: I18n.t("shared.exit"), value: :exit}
      ]
      Thread.main[:menu_runners][__method__.to_sym] ||= [
        {value: :in, proc: Proc.new{
          Aromancer::Api.sign_in
          authentication
        }},
        {value: :up, proc: Proc.new{
          Aromancer::Api.sign_up
          authentication
        }},
        {value: :configure, proc: Proc.new{
          configure
        }}
      ]
      Thread.main[:route] = __method__.to_sym
    end

    def self.configure
      cls

      Aromancer::Prompt.say(I18n.t("routes.configure.title", name: Aromancer.to_s.downcase))
      [
        Aromancer::Storage.get_server_url,
        Aromancer::Storage.get_websocket_url
      ].each{|l|
        Aromancer::Prompt.say(l)
      }

      server_url_update = Proc.new{|property|

        updated = nil
        storage_key = "server_url_#{property}"
        previous = Aromancer::Storage.instance.get_key(storage_key)
        while updated.nil? || updated.blank? || updated != Aromancer::Storage.instance.get_key(storage_key)
          # get user input
          updated = Aromancer::Prompt.p.ask(I18n.t("routes.configure.new_#{property}"))

          if property.to_sym == :port
            updated = updated.to_i
            next unless updated > 0
          end

          # set new host value in storage
          Aromancer::Storage.instance.set_key(storage_key, updated)

          confirmed = false
          begin
            confirmed = Aromancer::Prompt.p.ask(I18n.t("shared.update_confirm", new_value: Aromancer::Storage.get_server_url))
          rescue StandardError => e
            Aromancer::Prompt.say(e)
          end

          unless :y.to_s == confirmed
            # reset to old value
            Aromancer::Prompt.say(I18n.t("shared.update_cancel"))
            Aromancer::Storage.instance.set_key(storage_key, previous)
          end

          Aromancer::Storage.instance.clear_cache!
        end
        Aromancer::Prompt.say(I18n.t("shared.server_url", url: Aromancer::Storage.get_server_url))
      }

      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("shared.back"), value: :back},
        {name: I18n.t("routes.configure.server_host", stored: Aromancer::Storage.instance.get_key(:server_url_host)), value: :host},
        {name: I18n.t("routes.configure.server_port", stored: Aromancer::Storage.instance.get_key(:server_url_port)), value: :port},
        {name: I18n.t("routes.configure.force_ssl", stored: Aromancer::Storage.get_preference(:force_ssl)), value: :force_ssl},
        {name: I18n.t("routes.configure.debug", stored: Aromancer::Storage.get_preference(:debug)), value: :debug}
      ]

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{ main_menu }},
        {value: :host, proc: Proc.new{
          server_url_update.call(:host)
          configure
        }},
        {value: :port, proc: Proc.new{
          server_url_update.call(:port)
          configure
        }},
        {value: :force_ssl, proc: Proc.new{
          Aromancer::Storage.toggle_force_ssl
          Aromancer::Prompt.say(I18n.t("shared.server_url", url: Aromancer::Storage.get_server_url))
          Aromancer::Prompt.say(
            I18n.t("routes.configure.force_ssl_toggle", value: Aromancer::Storage.get_preference(:force_ssl))
          )
          sleep(2)
          configure
        }},
        {value: :debug, proc: Proc.new{
          Aromancer::Storage.toggle_preference(:debug)

          Aromancer::Prompt.say(
            I18n.t("routes.configure.debug_toggle", value: Aromancer::Storage.get_preference(:debug))
          )
          sleep(2)
          configure
        }},
      ]
      Thread.main[:route] = __method__.to_sym
    end

    def self.main_menu
      cls
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :main_menu)) if Aromancer::Storage.get_preference(:debug)
      if Aromancer::Storage.get_signed_out_flag
        Aromancer::Prompt.say(I18n.t("routes.main_menu.not_signed_in"))
        Aromancer::Api.sign_out
        Thread.main[:route] = :authentication
        Thread.main[:menu_options] = {}
        return authentication
      end

      player = Aromancer::Storage.get_player&.symbolize_keys
      al = active_legend
      return legend_menu if (!player.nil? && !player[:active_legend_id].nil?) ||
        (!al.nil? && al["status"] == "started")

      return authentication if player.nil?

      Thread.main[:menu_options][__method__.to_sym] ||= [
        {name: I18n.t("routes.main_menu.new_game"), value: :new},
        {name: I18n.t("routes.main_menu.load_game"), value: :load},
        {name: I18n.t("routes.main_menu.find_game"), value: :find},
        {name: I18n.t("routes.main_menu.configure"), value: :configure},
        {name: I18n.t("routes.main_menu.sign_out"), value: :out},
        {name: I18n.t("shared.exit"), value: :exit}
      ]

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :new, proc: Proc.new{
          # this will run on the main thread
          params = Aromancer::Api::DEFAULT_LEGEND_PARAMS.dup

          player_count = nil
          while player_count.nil? || ![1, 2].include?(player_count&.to_i)
            player_count = Aromancer::Prompt.p.ask(I18n.t("routes.main_menu.player_count"))
          end
          params[:player_count] = player_count
          Thread.main[:route_params] = [params]
          new_game(params)
        }},
        {value: :load, proc: Proc.new{ Aromancer::Routes::legends }},
        {value: :find, proc: Proc.new{ Aromancer::Routes::find_game }},
        {value: :configure, proc: Proc.new{
          configure
        }},
        {value: :out, proc: Proc.new{
          case Aromancer::Prompt.p.select(I18n.t("shared.confirm"), [:no, :yes], cycle: true, per_page: 11)
          when :no
            main_menu
          when :yes
            Aromancer::Api.sign_out
            authentication
          end
        }}
      ]
      Thread.main[:route] = __method__.to_sym
    end

    def self.new_game(params)
      cls
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :new_game)) if Aromancer::Storage.get_preference(:debug)

      data = [
        [I18n.t("routes.new_game.player_count"), params[:player_count]],
        [I18n.t("routes.new_game.story_count"), params[:story_count]],
        [I18n.t("routes.new_game.status"), params[:status]]
      ]
      table = TTY::Table.new(data)
      Aromancer::Prompt.say(table.render(:unicode))

      Aromancer::Prompt.say(I18n.t("routes.new_game.starting"))

      Thread.main[:menu_options][__method__.to_sym] = [
        {name: :continue, value: :continue},
        {name: :cancel, value: :cancel}
      ]
      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :continue, proc: Proc.new{
          Aromancer::Storage.instance.clear_cache!
          Aromancer::Api.create_legend(params)
          legend_menu
          # Aromancer::Api.get_legends

          # unless active_legend.nil? || active_legend["id"] != Aromancer::Storage.get_player["active_legend_id"]
          #   Aromancer.print_last_error
          #   sleep(1)
          #   main_menu
          # else
          #   legend_menu
          # end
        }},
        {value: :cancel, proc: Proc.new{
          Aromancer::Prompt.say(I18n.t("routes.new_game.cancelled"))
          main_menu
        }}
      ]
      Thread.main[:route] = __method__.to_sym
    end

    def self.find_game
      legends(JSON.parse(Aromancer::Server.find_legends.body || []))
    end

    def self.legends(legend_array = nil)

      # if legend_array.nil?, load player's legends
      if legend_array.nil?
        Aromancer::Storage.instance.clear_cache!
        Aromancer::Api.get_legends
        legend_array = Aromancer::Storage.get_legends
        unless legend_array.any?
          Aromancer::Prompt.say(I18n.t("shared.empty"))
          sleep(1)
          return main_menu
        end
      end

      Thread.main[:menu_options][__method__.to_sym] = [{name: I18n.t("shared.back"), value: :back}] + legend_array.map{|l|
        {
          name: "#{I18n.t("routes.legend.title")}_#{l["id"]} (#{l["status"]}) #{DateTime.parse(l["created_at"])&.strftime(Aromancer::Api::DATE_FORMAT)}",
          value: l["id"]
        }
      }

      if Aromancer::Storage.get_preference(:debug)
        Aromancer::Prompt.say(JSON.pretty_generate(legend_array))
      end

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{ main_menu }},
      ] + legend_array.map{|l|
        {
          value: l["id"],
          proc: Proc.new{
            Aromancer::Api.set_active_legend_id(l["id"])

            unless active_legend.nil? || active_legend["id"] != Aromancer::Storage.get_player["active_legend_id"]
              Aromancer.print_last_error
              sleep(1)
              main_menu
            else
              legend_menu
            end
          }
        }
      }
      Thread.main[:route] = __method__.to_sym
    end

    def self.stream
      Aromancer::Api.load_stream
      stream = Aromancer::Storage.get_stream
      Aromancer::Prompt.say(I18n.t("routes.stream.title"))
      Aromancer::Prompt.say([
        :timestamp,
        :description
      ].join(", "))

      stream["stream"].each{|e|
        Aromancer::Prompt.say("\n")
        Aromancer::Prompt.say([e["updated_at"], e["description"]].join("\n"))
      }

      Thread.main[:menu_options][__method__.to_sym] ||= [{name: I18n.t("shared.key_press"), value: nil}]
      Thread.main[:menu_runners][__method__.to_sym] ||= [
        {value: nil, proc: Proc.new{ legend_menu }}
      ]
      Thread.main[:route] = __method__.to_sym
    end

    def self.legend_menu
      cls
      legend

      legend_array = Aromancer::Storage.get_legends
      al = active_legend
      if !al.nil?
        if al["status"] == "complete"
          Aromancer::Api.set_active_legend_id(nil)
          Aromancer::Prompt.say(I18n.t("routes.legend.legend_complete"))
          return legends
        elsif al["status"] == "created"
          Thread.main[:menu_options][__method__.to_sym] = [
            {name: :reload, value: :reload}, {name: I18n.t("shared.back"), value: :back}
          ]
          Thread.main[:menu_runners][__method__.to_sym] ||= [
            {value: :reload, proc: Proc.new{ legend_menu }},
            {value: :back, proc: Proc.new{
              Aromancer::Api.set_active_legend_id(nil)
              main_menu
            }}
          ]
          Thread.main[:route] = __method__.to_sym
          return
        end
      end
      hs = Aromancer::Storage.get_preference(:hide_sentences)
      hs_value = "#{hs ? "" : "hide_"}signed_sentences".to_sym

      Thread.main[:route] = __method__.to_sym
      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("routes.legend.unspoken_words"), value: :words},
        {name: I18n.t("routes.legend.spoken_words"), value: :spoken_words},
        {name: I18n.t("routes.legend.unsigned_sentences"), value: :unsigned_sentences},
        {name: I18n.t("routes.legend.#{hs_value}"), value: hs_value},
        {name: I18n.t("routes.stream.title"), value: :stream},
        {name: I18n.t("routes.main_menu.title"), value: :main_menu}
      ]

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :words, proc: Proc.new{ words }},
        {value: :spoken_words, proc: Proc.new{ spoken_words }},
        {value: :unsigned_sentences, proc: Proc.new{ unsigned_sentences }},
        {value: hs_value, proc: Proc.new{
          Aromancer::Storage.toggle_preference(:hide_sentences)
          legend_menu
        }},
        {value: :stream, proc: Proc.new{ stream }},
        {value: :main_menu, proc: Proc.new{
          Aromancer::Api.set_active_legend_id(nil)
          main_menu
        }},
      ]
    end

    def self.legend
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :legend)) if Aromancer::Storage.get_preference(:debug)
      Aromancer::Api.load_arena
      arena = arena_data
      al = active_legend
      al_status = ((al || {})["status"] || "").to_sym
      if !al.nil? &&
        [:created, :complete].include?(al_status)
        Aromancer::Prompt.say(arena["title"])
        Aromancer::Prompt.say(I18n.t("routes.legend.title"))
        Aromancer::Prompt.say(I18n.t("routes.legend.subtitle", subtitle: al["status"]))
        Aromancer::Prompt.say(I18n.t("routes.legend.players"))
        Aromancer::Prompt.say(JSON.pretty_generate(arena["players"]))
        Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
        if al_status == :complete
          Aromancer::Api.set_active_legend_id(nil)
          sleep(1)
          return main_menu
        else
          Aromancer::Api.get_legends
          legend_menu
        end
      end

      return if arena.nil? || arena["turn_player"].nil?

      # todo: pre-calculate needed widths. this isn't really working
      word_width = 5.0
      wpr = (TTY::Screen.width / word_width).floor

      # puts "wpr: #{wpr}"
      # puts TTY::Screen.width

      turn_player = arena["turn_player"]

      # title
      Aromancer::Prompt.say("\n\n")
      data = [
        [arena["title"]],
        ["#{turn_player["alias"]}'s turn"],
        ["dealer is #{arena["dealer"]["alias"]}"]
      ]
      title_table = TTY::Table.new(data)
      Aromancer::Prompt.say(title_table.render(:ascii))

      # players
      data = [
        [I18n.t("routes.legend.players")] + arena["players"].map{|p| "#{p["alias"]} (#{p["score"]})"}
      ]
      players_table = TTY::Table.new(data)
      Aromancer::Prompt.say(players_table.render(:ascii))

      # spoken words
      Aromancer::Prompt.say(I18n.t("routes.legend.spoken_words"))

      data = arena["scroll_words"].map{|sw| sw["value_display"]}.each_slice(wpr).to_a || []
      while data.any? && data.last.length < data.first.length
        data.last << ""
      end
      spoken_words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(spoken_words_table.render(:unicode))

      unless arena["sentences"].empty?
        # unsigned sentences
        Aromancer::Prompt.say(I18n.t("routes.legend.unsigned_sentences"))
        data = arena["sentences"].map{|sw| sw["value_display"]}.each_slice(wpr).to_a || []
        while data.any? && data.last.length < data.first.length
          data.last << ""
        end
        unsigned_sentences_table = TTY::Table.new(data)
        Aromancer::Prompt.say(unsigned_sentences_table.render(:unicode))
      end

      # unspoken words
      Aromancer::Prompt.say(I18n.t("routes.legend.unspoken_words"))
      data = arena["player"]["words"].map{|w| w["value_display"]}.each_slice(wpr).to_a || []
      while data.any? && data.last.length < data.first.length
        data.last << ""
      end
      words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(words_table.render(:ascii))

      unless arena["player"]["sentences"].empty?
        # signed sentences
        Aromancer::Prompt.say("#{I18n.t("routes.legend.signed_sentences")} (#{arena["player"]["sentences"].length})")
        unless Aromancer::Storage.get_preference(:hide_sentences)
          data = arena["player"]["sentences"].map{|s| s["value_display"]}.each_slice(wpr).to_a || []
          while data.any? && data.last.length < data.first.length
            data.last << ""
          end
          sentences_table = TTY::Table.new(data)
          Aromancer::Prompt.say(sentences_table.render(:ascii))
        end
      end
    end

    def self.words
      cls
      legend

      arena = arena_data
      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("shared.back"), value: :back}
      ] + arena["player"]["words"].map{|w| {name: w["value_display"], value: w["id"]}}

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{ legend_menu }}
      ] + arena["player"]["words"].map{|w|
        {value: w["id"], proc: Proc.new{
          word(w["id"])
        }}
      }
      Thread.main[:route] = __method__.to_sym
    end

    def self.spoken_words
      cls
      legend

      arena = arena_data
      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("shared.back"), value: :back}
      ] + arena["scroll_words"].map{|w| {name: w["value_display"], value: w["id"]}}

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{ legend_menu }}
      ] + arena["scroll_words"].map{|w|
        {value: w["id"], proc: Proc.new{
           word(w["id"])
        }}
      }
      Thread.main[:route] = __method__.to_sym
    end

    def self.unsigned_sentences
      cls
      legend

      arena = arena_data
      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("shared.back"), value: :back}
      ] + arena["sentences"].map{|s| {name: "id: #{s["id"]}, value: #{s["value"]}", value: s["id"]}}

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{ legend_menu }}
      ] + arena["sentences"].map{|s|
        ss_words = s["words"]
        wid = ss_words.first["id"]

        {value: s["id"], proc: Proc.new{word(wid)}}
      }
      Thread.main[:route] = __method__.to_sym
    end

    def self.word(selected_word_id)
      return legend_menu if selected_word_id.nil?

      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :word)) if Aromancer::Storage.get_preference(:debug)
      possibilities = Aromancer::Api.load_word_possibilities(selected_word_id)

      if Aromancer::Storage.get_preference(:debug)
        Aromancer::Prompt.say(JSON.pretty_generate(possibilities))
      end

      options = possibilities["options"]
      selected_word = possibilities["word"]
      for_type = possibilities["for_type"].to_sym

      arena = arena_data
      player_words = arena["player"]["words"]

      choices = [{name: I18n.t("shared.back"), value: :back}]
      if for_type == :player_word

        # show place on scroll option if selected word is from player's words
        choices << {
          name: I18n.t("routes.legend.place_on_scroll", word: selected_word["value_display"]),
          value: :player_word
        }
      end

      choices += options.map{|o| {name: "#{o["humanized_title"]} -> weight: #{o["total_weight"]}", value: o}}

      Thread.main[:menu_options][__method__.to_sym] = choices
      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :back, proc: Proc.new{
          case for_type
          when :player_word
            words
          when :scroll_word
            spoken_words
          when :scroll_sentence
            unsigned_sentences
          end
        }},
        {value: :player_word, proc: Proc.new{
          wytyd = I18n.t("routes.legend.place_on_scroll", word: selected_word["value_display"])
          Aromancer::Prompt.say(wytyd)
          Aromancer::Api.create_turn({
            wytyd: wytyd,
            word_id: selected_word["id"]
          })
          legend_menu
        }},
        {value: nil, proc: Proc.new{|o|
          if o["http_verb"] == "post"
            Aromancer::Api.create_turn(JSON.parse(o["payload"]))
          else
            Aromancer::Api.update_turn(JSON.parse(o["payload"]))
          end

          legend_menu
        }}
      ]
      Thread.main[:route_params] = [selected_word_id]
      Thread.main[:route] = __method__.to_sym
    end
  end
end