# frozen_string_literal: true

=begin

  api.rb

  aromancer api.

  by i2097i

=end

module Aromancer
  class Api

    DATE_FORMAT = "%A %d %b %Y %I:%M:%S %p"

    def self.storage_headers(result)
      result.kind_of?(Aromancer::Server::InternalError) ? nil : result.headers
    end

    def self.register_error(response)
      Aromancer::Storage.set_last_error({
        status: response.status,
        headers: storage_headers(response),
        body: response.body.to_s[0..444]
      })

      signed_out = false
      signed_out = response.status == 401
      error_body = nil
      begin
        error_body = JSON.parse(response.body)
      rescue StandardError => e
      end

      signed_out = signed_out &&
        !error_body.nil? &&
        error_body.keys.include?(:error_message.to_s) &&
        error_body["error_message"] == "not signed in"

      Aromancer::Storage.instance.clear_cache! if signed_out
      Aromancer::Storage.set_signed_out_flag(signed_out)
    end

    def self.sign_in
      email_address = nil
      password = nil
      while email_address.nil? || email_address.blank?
        email_address = Aromancer::Prompt.p.ask("enter email address:")
      end

      while password.nil? || password.blank?
        password = Aromancer::Prompt.p.mask("enter password:")
      end

      result = Aromancer::Server.sign_in(email_address, password)
      if result.status == 201
        response = JSON.parse(result.body)
        Aromancer::Storage.set_player(response)
      else
        Aromancer::Storage.set_player(nil)
        register_error(result)
      end
    end

    def self.sign_up
      email_address = nil
      password = nil
      password_confirmation = nil
      while email_address.nil? || email_address.blank?
        email_address = Aromancer::Prompt.p.ask("enter email address:")
      end

      while password.nil? || password.blank?
        password = Aromancer::Prompt.p.mask("enter password:")
      end

      while password_confirmation.nil? || password_confirmation.blank?
        password_confirmation = Aromancer::Prompt.p.mask("confirm password:")
      end

      result = Aromancer::Server.sign_up(email_address, password, password_confirmation)
      if result.status == 201
        response = JSON.parse(result.body)
        Aromancer::Storage.set_player(response)
      else
        Aromancer::Storage.set_player(nil)
        register_error(result)
      end
    end

    def self.sign_out
      result = Aromancer::Server.sign_out
      # clear storage
      Aromancer::Storage.set_player(nil)
      Aromancer::Storage.set_last_error(nil)
      FileUtils.rm_rf(Aromancer::Storage.storage_filepath)

      register_error(result) if result.status != 200
    end

    DEFAULT_LEGEND_PARAMS = {
      status: :created,
      player_count: 1,
      story_count: 1
    }

    def self.create_legend(params = Aromancer::Api::DEFAULT_LEGEND_PARAMS)
      result = Aromancer::Server.create_legend({legend: params})
      if result.status == 201
        response = JSON.parse(result.body)
        set_active_legend_id(response["id"])
      else
        register_error(result)
      end
    end

    def self.get_legends
      result = Aromancer::Server.get_legends
      if result.status == 200
        response = JSON.parse(result.body)
        Aromancer::Storage.set_legends(response)
      else
        Aromancer::Storage.set_legends([])
        register_error(result)
      end
    end

    def self.set_active_legend_id(active_legend_id)
      result = Aromancer::Server.update_player({player: {
        active_legend_id: active_legend_id,
        status: active_legend_id.nil? ? :lobby : :playing
      }})

      if result.status == 200
        response = JSON.parse(result.body)
        Aromancer::Storage.set_player(response)
      else
        register_error(result)
      end
    end

    def self.load_arena
      result = Aromancer::Server.get_arena
      if result.status == 200
        response = JSON.parse(result.body)
        Aromancer::Storage.set_arena(response)
      else
        Aromancer::Storage.set_arena(nil)
        register_error(result)
      end
    end

    def self.load_stream
      result = Aromancer::Server.get_stream

      if result.status == 200
        response = JSON.parse(result.body)

        Aromancer::Storage.set_stream(response)
      else
        Aromancer::Storage.set_stream(nil)
        register_error(result)
      end
    end

    def self.load_word_possibilities(selected_word_id)
      result = Aromancer::Server.get_word_possibilities(selected_word_id)
      if result.status == 200
        return JSON.parse(result.body)
      else
        register_error(result)
      end
    end

    def self.create_turn(arena_params)
      result = Aromancer::Server.create_turn({arena: arena_params})
      if result.status == 201
        response = JSON.parse(result.body)
        load_arena
      else
        register_error(result)
      end
    end

    def self.update_turn(arena_params)
      result = Aromancer::Server.update_turn({arena: arena_params})
      if result.status == 200
        response = JSON.parse(result.body)
        load_arena
      else
        register_error(result)
      end
    end

  end

end