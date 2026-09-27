# frozen_string_literal: true

=begin

  routes.rb

  view routing and configuration.

  by i2097i

=end

module Aromancer
  class Routes

    def self.cls
      TTY::Cursor.clear_screen
      TTY::Cursor.clear_screen_up
    end

    def self.authentication(require_key_press = false)
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :authentication))
      Aromancer::Prompt.p.ask(I18n.t("shared.key_press")) if require_key_press

      choices = [
        {name: I18n.t("routes.authentication.sign_in"), value: :in},
        {name: I18n.t("routes.authentication.sign_up"), value: :up},
        {name: I18n.t("shared.exit"), value: :exit}
      ]
      text = ""#Aromancer.get_font(I18n.t("routes.authentication.title")).join("\n") +
        "\n#{I18n.t("routes.authentication.subtitle")}"
      case Aromancer::Prompt.p.select(text, choices, show_help: :always, cycle: true, per_page: 11)
      when :in
        Aromancer::Api.sign_in
      when :up
        Aromancer::Api.sign_up
      else
        exit
      end

      if Aromancer::Storage.get_player
        Aromancer::Storage.set_signed_out_flag(false)
        main_menu
      else
        Aromancer.print_last_error("routes.authentication.failed")
        authentication(true)
      end
    end

    def self.active_legend
      Aromancer::Api.get_legends
      Aromancer::Storage.get_legends.select{|l| l["id"] == Aromancer::Storage.get_player["active_legend_id"]}.first
    end

    def self.main_menu
      cls
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :main_menu))
      if Aromancer::Storage.get_signed_out_flag
        Aromancer::Prompt.say(I18n.t("routes.main_menu.not_signed_in"))
        Aromancer::Api.sign_out
        return authentication
      end

      player = Aromancer::Storage.get_player&.symbolize_keys
      al = active_legend
      return legend_menu if (!player.nil? && !player[:active_legend_id].nil?) ||
        (!al.nil? && al["status"] == "started")

      choices = [
        {name: I18n.t("routes.main_menu.new_game"), value: :new},
        {name: I18n.t("routes.main_menu.load_game"), value: :load},
        {name: I18n.t("routes.main_menu.sign_out"), value: :out},
        {name: I18n.t("shared.exit"), value: :exit}
      ]
      text = ""#Aromancer.get_font(I18n.t("routes.main_menu.title")).join("\n") +
        "\n#{I18n.t("routes.main_menu.subtitle")}"
      case Aromancer::Prompt.p.select(text, choices, show_help: :always, cycle: true, per_page: 11)
      when :new
        new_game
      when :load
        legends
      when :out
        case Aromancer::Prompt.p.select(I18n.t("shared.confirm"), [:no, :yes], cycle: true, per_page: 11)
        when :no
          main_menu
        when :yes
          Aromancer::Api.sign_out
          authentication
        end
      else
        exit
      end
    end

    def self.new_game
      cls
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :new_game))
      params = Aromancer::Api::DEFAULT_LEGEND_PARAMS.dup
      data = [
        [I18n.t("routes.new_game.player_count"), params[:player_count]],
        [I18n.t("routes.new_game.story_count"), params[:story_count]],
        [I18n.t("routes.new_game.status"), params[:status]]
      ]
      table = TTY::Table.new(data)
      Aromancer::Prompt.say(table.render(:unicode))

      # TODO: edit params here

      Aromancer::Prompt.say(I18n.t("routes.new_game.starting"))
      Aromancer::Api.create_legend(params)
      Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))

      main_menu
    end

    def self.legends
      Aromancer::Api.get_legends
      legend_array = Aromancer::Storage.get_legends
      unless legend_array.any?
        Aromancer::Prompt.say(I18n.t("shared.empty"))
        Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
        main_menu
      end
      choices = [{name: :back, value: :back}] + legend_array.map{|l|
        {
          name: "#{I18n.t("routes.legend.title")}_#{l["id"]} (#{l["status"]}) #{DateTime.parse(l["created_at"])&.strftime(Aromancer::Api::DATE_FORMAT)}",
          value: l["id"]
        }
      }
      selected_legend_id = Aromancer::Prompt.p.select("", choices, help: I18n.t("routes.legends.help"), show_help: :always, cycle: true, per_page: 11)

      if selected_legend_id == :back
        return main_menu
      end

      Aromancer::Api.set_active_legend_id(selected_legend_id)
      legend_menu
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
      Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
      legend_menu
    end

    def self.legend_menu
      cls
      # Aromancer::Prompt.say(I18n.t("shared.navigate", route: :legend_menu))
      legend

      legend_array = Aromancer::Storage.get_legends
      al = active_legend
      if !al.nil? && al["status"] == "complete"
        Aromancer::Api.set_active_legend_id(nil)
        Aromancer::Prompt.say(I18n.t("routes.legend.legend_complete"))
        Aromancer::Prompt.p.ask(I18n.t("shared.key_press"))
        return legends
      end

      hs = Aromancer::Storage.get_preference(:hide_sentences, default: true)
      hs_value = "#{hs ? "" : "hide_"}signed_sentences".to_sym
      choices = [
        {name: I18n.t("routes.legend.unspoken_words"), value: :words},
        {name: I18n.t("routes.legend.spoken_words"), value: :spoken_words},
        {name: I18n.t("routes.legend.unsigned_sentences"), value: :unsigned_sentences},
        {name: I18n.t("routes.legend.#{hs_value}"), value: hs_value},
        {name: I18n.t("routes.stream.title"), value: :stream},
        {name: I18n.t("routes.main_menu.title"), value: :main_menu}
      ]
      text = ""#Aromancer.get_font(I18n.t("routes.legend_menu.title")).join("\n") +
        "\n#{I18n.t("routes.legend_menu.subtitle")}"
      case Aromancer::Prompt.p.select(text, choices, help: I18n.t("routes.legend_menu.help"), show_help: :always, cycle: true, per_page: 11)
      when :words
        words
      when :spoken_words
        spoken_words
      when :unsigned_sentences
        unsigned_sentences
      when hs_value
        Aromancer::Storage.set_preference(:hide_sentences, !hs)
        legend_menu
      when :stream
        stream
      when :main_menu
        Aromancer::Api.set_active_legend_id(nil)
        main_menu
      end
    end

    def self.legend
      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :legend))
      Aromancer::Api.load_arena
      arena = arena_data

      # puts arena.to_json
      turn_player = arena["turn_player"]

      # title
      Aromancer::Prompt.say("\n\n")
      data = [
        [arena["title"]],
        ["#{
          turn_player["id"] == Aromancer::Storage.get_player["id"] ?
          "your" :
          "#{turn_player["alias"]}'s"
        } turn"],
        ["dealer is #{arena["dealer"]["alias"]}"]
      ]
      title_table = TTY::Table.new(data)
      Aromancer::Prompt.say(title_table.render(:ascii))

      # players
      data = [
        [I18n.t("routes.legend.players")] + arena["players"].map{|p| p["alias"]}
      ]
      players_table = TTY::Table.new(data)
      Aromancer::Prompt.say(players_table.render(:ascii))

      # spoken words
      Aromancer::Prompt.say(I18n.t("routes.legend.spoken_words"))
      data = [
        arena["scroll_words"].map{|sw| sw["value_display"]}
      ]
      spoken_words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(spoken_words_table.render(:unicode))

      unless arena["sentences"].empty?
        # unsigned sentences
        Aromancer::Prompt.say(I18n.t("routes.legend.unsigned_sentences"))
        data = [
          arena["sentences"].map{|sw| "#{sw["value"]} (#{sw["words"].map{|w| w["value_display"]}.sort.join(", ")})"}
        ]
        unsigned_sentences_table = TTY::Table.new(data)
        Aromancer::Prompt.say(unsigned_sentences_table.render(:unicode))
      end

      # unspoken words
      Aromancer::Prompt.say(I18n.t("routes.legend.unspoken_words"))
      data = [
        arena["player"]["words"].map{|w| w["value_display"]}
      ]
      words_table = TTY::Table.new(data)
      Aromancer::Prompt.say(words_table.render(:ascii))

      unless arena["player"]["sentences"].empty? || Aromancer::Storage.get_preference(:hide_sentences, default: true)
        # signed sentences
        Aromancer::Prompt.say(I18n.t("routes.legend.signed_sentences"))
        data = [
          arena["player"]["sentences"].map{|s|
            "#{s["value"]}: " + (
              [s["signature"]["value_display"]] + s["words"].map{|w|
                w["value_display"]
              }
            ).join(", ")
          }
        ]
        sentences_table = TTY::Table.new(data)
        Aromancer::Prompt.say(sentences_table.render(:ascii))
      end
    end

    def self.words
      cls
      legend

      arena = arena_data
      choices = [{name: :back, value: :back}] + arena["player"]["words"].map{|w| {name: w["value_display"], value: w["id"]}}
      selected_word_id = Aromancer::Prompt.p.select("", choices, show_help: :always, cycle: true, per_page: 11)

      if selected_word_id == :back
        return legend_menu
      end

      word(selected_word_id)
    end

    def self.word(selected_word_id)
      return legend_menu if selected_word_id.nil?

      Aromancer::Prompt.say(I18n.t("shared.navigate", route: :word))
      possibilities = Aromancer::Api.load_word_possibilities(selected_word_id)

      # todo: hide/show this
      puts JSON.pretty_generate possibilities

      options = possibilities["options"]
      selected_word = possibilities["word"]
      for_type = possibilities["for_type"].to_sym

      arena = arena_data
      player_words = arena["player"]["words"]

      option_display = Proc.new{|o, sw|
        a = o["action"].humanize.downcase
        o_value = ""
        o_value_display = ""
        if o["sentence"].nil?
          o_value = o["word"]["value"]
          o_value_display = o["word"]["value_display"]
        else
          o_value = o["sentence"]["value"]
          o_value_display = "#{o_value} (#{I18n.t("routes.legend.sentences")})"
        end
        # todo: this sucks
        # case a
        # when :can_sign
        # when :can_combine
        # when :can_stack
        # end
        calc = "(#{sw["value"]} + #{o_value} = #{sw["value"] + o_value})"

        "#{sw["value_display"]} #{a} #{o_value_display} #{calc}"
      }

      choices = [
        {name: :back, value: :back}
      ]
      if for_type == :player_word
        # show place on scroll option if selected word is from player's words
        choices << {name: I18n.t("routes.legend.place_on_scroll", word: selected_word["value_display"]), value: :player_word}
      end
      choices += options.map{|o| {name: option_display.call(o, selected_word), value: o}}
      selected_option = Aromancer::Prompt.p.select(
        I18n.t("routes.legend.options_for_word", word: selected_word["value_display"]),
        choices,
        show_help: :always, cycle: true, per_page: 11
      )

      if selected_option == :back
        return case for_type
        when :player_word
          words
        when :scroll_word
          spoken_words
        when :scroll_sentence
          unsigned_sentences
        end
      elsif selected_option == :player_word
        wytyd = I18n.t("routes.legend.place_on_scroll", word: selected_word["value_display"])
        Aromancer::Prompt.say(wytyd)
        Aromancer::Api.create_turn({
          wytyd: wytyd,
          word_id: selected_word["id"]
        })
        legend_menu
      else
        if selected_option["http_verb"] == "post"
          Aromancer::Api.create_turn(JSON.parse(selected_option["payload"]))
        else
          Aromancer::Api.update_turn(JSON.parse(selected_option["payload"]))
        end

        legend_menu
      end
    end

    def self.spoken_words
      cls
      legend

      arena = arena_data
      choices = [{name: :back, value: :back}] + arena["scroll_words"].map{|w| {name: w["value_display"], value: w["id"]}}
      selected_word_id = Aromancer::Prompt.p.select(I18n.t("routes.legend.spoken_words"), choices, show_help: :always, cycle: true, per_page: 11)

      if selected_word_id == :back
        return legend_menu
      end

      word(selected_word_id)
    end

    def self.unsigned_sentences
      cls
      legend

      arena = arena_data
      choices = [{name: :back, value: :back}] + arena["sentences"].map{|s| {name: "id: #{s["id"]}, value: #{s["value"]}", value: s}}
      selected_sentence = Aromancer::Prompt.p.select(I18n.t("routes.legend.unsigned_sentences"), choices, show_help: :always, cycle: true, per_page: 11)

      if selected_sentence == :back
        return legend_menu
      end

      return legend_menu if selected_sentence.nil?
      ss_words = selected_sentence["words"]
      return legend_menu if  ss_words.nil? || ss_words.empty?

      word(selected_sentence["words"].first["id"])
    end

    def self.arena_data
      arena = Aromancer::Storage.get_arena
      if arena.nil?
        Aromancer.print_last_error("routes.legend.arena_failed")
        Aromancer::Api.set_active_legend_id(nil)
        main_menu
      else
        arena
      end
    end

  end
end