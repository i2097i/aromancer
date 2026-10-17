# frozen_string_literal: true

=begin

  routes.rb

  view routing and configuration.

  by i2097i

=end

module Aromancer
  class Routes

    WIDTH_MULTIPLIER = TTY::Screen.width / 4.0

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
      end
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
        Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
        Aromancer::Api.set_active_legend_id(nil)
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

    def self.rules
      return if Thread.main[:route] == __method__.to_sym
      rules = Aromancer::Api.load_rules
      Aromancer::Prompt.say(rules["rules"], ljust: true)

      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("shared.key_press"), value: :key_press}
      ]
      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :key_press, proc: Proc.new{ main_menu }}
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
        {name: I18n.t("routes.main_menu.rules"), value: :rules},
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
        {value: :rules, proc: Proc.new{
          rules
        }},
        {value: :out, proc: Proc.new{
          case Aromancer::Prompt.p.select(I18n.t("shared.confirm"), [:no, :yes], cycle: true, per_page: 11)
          when :no
            main_menu
          when :yes
            Aromancer::Api.sign_out
            authentication
          end
        }},
        {value: :exit, proc: Proc.new{
          exit
        }},
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
          name: "#{l["value_display"]} > #{l["status"]} > #{Aromancer.date_display(l["created_at"])}",
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

    def self.stream(display_only: false, recent_count: nil)
      return if Thread.main[:route] == __method__.to_sym
      Aromancer::Prompt.print_divider(I18n.t("routes.stream.title"))
      Aromancer::Api.load_stream(recent_count)
      stream = Aromancer::Storage.get_stream
      stream["stream"].last(
        recent_count.nil? ? stream["stream"].count : recent_count
      ).each{|e|
        Aromancer::Prompt.say("[#{Aromancer.time_display(e["updated_at"])}]: #{e["description"]}", ljust: true)
      }
      Aromancer::Prompt.print_divider(I18n.t("routes.stream.end"))
      return if display_only

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
          Thread.main[:menu_options][__method__.to_sym] = [
            {name: I18n.t("shared.key_press"), value: :key_press}
          ]
          Thread.main[:menu_runners][__method__.to_sym] = [
            {value: :key_press, proc: Proc.new{
              Aromancer::Prompt.say(I18n.t("routes.legend.returning_to_main"))
              Aromancer::Api.set_active_legend_id(nil)
              legends
            }}
          ]
          Thread.main[:route] = __method__.to_sym
          return
        elsif al["status"] == "created"
          Thread.main[:menu_options][__method__.to_sym] = [
            {name: :reload, value: :reload}, {name: I18n.t("shared.back"), value: :back}
          ]
          Thread.main[:menu_runners][__method__.to_sym] = [
            {value: :reload, proc: Proc.new{ legend_menu }},
            {value: :back, proc: Proc.new{
              Aromancer::Api.set_active_legend_id(nil)
              legends
            }}
          ]
          Thread.main[:route] = __method__.to_sym
          return
        elsif active_legend["player"] && (active_legend["player"]["words"] || []).count == 0
          Aromancer::Api.load_arena
          return
        end
      else
        Thread.main[:menu_runners] = {}
        Thread.main[:menu_options] = {}
        Thread.main[:route] = :main_menu
      end

      hide_sentences_pref = Aromancer::Storage.get_preference(:hide_sentences)
      hide_sentences_pref_value = "#{hide_sentences_pref ? "" : "hide_"}signed_sentences".to_sym
      hide_stream_pref = Aromancer::Storage.get_preference(:hide_stream)
      hide_stream_pref_value = "#{hide_stream_pref ? "" : "hide_"}title".to_sym

      Thread.main[:route] = __method__.to_sym
      Thread.main[:menu_options][__method__.to_sym] = [
        {name: I18n.t("routes.legend.unspoken_words"), value: :words},
        {name: I18n.t("routes.legend.spoken_words"), value: :spoken_words},
        {name: I18n.t("routes.legend.unsigned_sentences"), value: :unsigned_sentences},
        {name: I18n.t("routes.legend.#{hide_sentences_pref_value}"), value: hide_sentences_pref_value},
        {name: I18n.t("routes.stream.#{hide_stream_pref_value}"), value: hide_stream_pref_value},
        {name: I18n.t("routes.main_menu.title"), value: :main_menu}
      ]

      Thread.main[:menu_runners][__method__.to_sym] = [
        {value: :words, proc: Proc.new{ words }},
        {value: :spoken_words, proc: Proc.new{ spoken_words }},
        {value: :unsigned_sentences, proc: Proc.new{ unsigned_sentences }},
        {value: hide_sentences_pref_value, proc: Proc.new{
          Aromancer::Storage.toggle_preference(:hide_sentences)
          legend_menu
        }},
        {value: hide_stream_pref_value, proc: Proc.new{
          Aromancer::Storage.toggle_preference(:hide_stream)
          legend_menu
        }},
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

        stream(display_only: true) # display entire stream
        Aromancer::Prompt.print_divider(al["value_display"])
        Aromancer::Prompt.say(arena["title"])
        Aromancer::Prompt.say(arena["players"].map{|p| "#{p["alias"]}(#{p["score"]})"}.join(" | "))

        if al_status == :complete
          Thread.main[:menu_options][:legend_menu] = [
            {name: I18n.t("shared.key_press"), value: :key_press}
          ]
          Thread.main[:menu_runners][:legend_menu] = [
            {value: :key_press, proc: Proc.new{
              Aromancer::Prompt.say(I18n.t("routes.legend.returning_to_main"))
              Aromancer::Api.set_active_legend_id(nil)
              legends
            }}
          ]
        else
          Aromancer::Api.get_legends

          Thread.main[:menu_options][:legend_menu] = [
            {name: I18n.t("shared.back"), value: :back},
            {name: I18n.t("shared.key_press"), value: :key_press}
          ]
          Thread.main[:menu_runners][:legend_menu] = [
            {value: :back, proc: Proc.new{
              Aromancer::Prompt.say(I18n.t("routes.legend.returning_to_main"))
              Aromancer::Api.set_active_legend_id(nil)
              legends
            }},
            {value: :key_press, proc: Proc.new{ legend_menu }}
          ]
        end
        return
      end

      return if arena.nil? || arena["turn_player"].nil?

      turn_player = arena["turn_player"]

      # title
      Aromancer::Prompt.say("\n")
      ([
          "#{I18n.t("routes.legend.title")}: #{(active_legend || {})["value_display"]}",
          "#{arena["title"]}: #{turn_player["alias"]}'s turn. dealer is #{arena["dealer"]["alias"]}"
        ] + arena["players"].map{|p| "#{p["alias"].rjust(11)} (#{p["score"]})"}
      ).each{|l| Aromancer::Prompt.say(l, rjust: true)}

      if !arena["bot_player"].nil?
        # todo: show/hide preference
        render_alchemy_for(arena["bot_player"])
      end
      render_scroll(arena)
      render_alchemy_for(arena["player"])
    end

    # todo: move this to helper class. not a route
    def self.render_scroll(arena)
      Aromancer::Prompt.print_divider(I18n.t("routes.legend.scroll"))
      # spoken words
      Aromancer::Prompt.say(I18n.t("routes.legend.spoken_words"))
      Aromancer::Prompt.say("\n")
      data = arena["scroll_words"].map{|sw| sw["value_display"]}.each_slice(Aromancer::Routes::WIDTH_MULTIPLIER).to_a || []
      while data.any? && data.last.length < data.first.length
        data.last << ""
      end
      spoken_words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(spoken_words_table.render(:unicode))

      unless arena["sentences"].empty?
        # unsigned sentences
        Aromancer::Prompt.say(I18n.t("routes.legend.unsigned_sentences"))
        Aromancer::Prompt.say("\n")
        data = arena["sentences"].map{|sw| sw["value_display"]}.each_slice(Aromancer::Routes::WIDTH_MULTIPLIER).to_a || []
        while data.any? && data.last.length < data.first.length
          data.last << ""
        end
        unsigned_sentences_table = TTY::Table.new(data)
        Aromancer::Prompt.say(unsigned_sentences_table.render)
      end
    end

    # todo: move this to helper class. not a route
    def self.render_alchemy_for(player)
      # unspoken words
      if player["id"].to_i != Aromancer::Storage.get_player["id"].to_i
        Aromancer::Prompt.print_divider(I18n.t("routes.legend.alchemy_for", name: player["alias"]))
      else
        Aromancer::Prompt.print_divider(I18n.t("routes.legend.your_alchemy"))
      end
      Aromancer::Prompt.say(I18n.t("routes.legend.unspoken_words"))
      Aromancer::Prompt.say("\n\n")
      words = player["words"].map{|w| w["value_display"]}
      data = words.each_slice(Aromancer::Routes::WIDTH_MULTIPLIER).to_a || []
      while data.any? && data.last.length < data.first.length
        data.last << ""
      end
      words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(words_table.render(:ascii))

      unless player["sentences"].empty?
        # signed sentences
        Aromancer::Prompt.say("#{I18n.t("routes.legend.signed_sentences")} (#{player["sentences"].length})")
        unless Aromancer::Storage.get_preference(:hide_sentences)
          data = player["sentences"].map{|s| s["value_display"]}.each_slice(Aromancer::Routes::WIDTH_MULTIPLIER).to_a || []
          while data.any? && data.last.length < data.first.length
            data.last << ""
          end
          sentences_table = TTY::Table.new(data)
          Aromancer::Prompt.say(sentences_table.render)
        end
        Aromancer::Prompt.say("\n\n")
      end

      unless player["id"].to_i != Aromancer::Storage.get_player["id"].to_i ||
        Aromancer::Storage.get_preference(:hide_stream)

        stream(display_only: true, recent_count: 5)
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
      ] + arena["sentences"].map{|s| {name: s["value_display"], value: s["id"]}}

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
      request_uuid = possibilities["uuid"]
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
          Aromancer::Api.submit_turn(request_uuid)
          legend_menu
        }},
        {value: nil, proc: Proc.new{|o|
          Aromancer::Api.submit_turn(request_uuid, {option_uuid: o[:uuid.to_s]})
          legend_menu
        }}
      ]
      Thread.main[:route_params] = [selected_word_id]
      Thread.main[:route] = __method__.to_sym
    end
  end
end