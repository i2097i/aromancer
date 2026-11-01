# frozen_string_literal: true

=begin

  storage.rb

  json data store

  by i2097i

=end

module Aromancer
  class Storage
    include Singleton

    VALID_KEYS = [
      :arena,
      :last_error,
      :legends,
      :player,
      :preference_debug,
      :preference_force_ssl,
      :preference_hide_sentences,
      :preference_hide_stream,
      :server_url_host,
      :server_url_port,
      :server_url_scheme,
      :signed_out_flag,
      :stream,
      :websocket_path,
      :websocket_scheme
   ]

   PERSISTED_KEYS = [
      :last_error,
      :player,
      :preference_debug,
      :preference_force_ssl,
      :preference_hide_sentences,
      :preference_hide_stream,
      :server_url_host,
      :server_url_port,
      :server_url_scheme,
      :websocket_path,
      :websocket_scheme
    ]

    URI_KEYS = [
      :scheme,
      :host,
      :port
    ]

    DEFAULT_PREFERENCES = {
      preference_debug: false,
      preference_force_ssl: false,
      preference_hide_sentences: true,
      preference_hide_stream: true,
    }

    DEFAULT_SERVER_URL = :"http://127.0.0.1:3000".to_s

    attr_accessor :storage_open, :cache, :clear_flag, :parser_error

    def initialize
      reload!
    end

    def ensure_default_preferences_exist
      DEFAULT_PREFERENCES.each{|d_key, d_value|
        current_value = get_key(d_key)
        if current_value.nil? || ![TrueClass, FalseClass].include?(current_value.class)
          set_key(d_key.to_s, d_value)
        end
      }
    end

    def reload!
      @storage_open = false
      @clear_flag = false
      @parser_error = nil
      clear_cache!
      Aromancer.configure_home
    end

    def clear_cache!
      if @storage_open
        @clear_flag = true
        return
      end
      @clear_flag = false
      @storage_open = false

      @cache = {} # clear'd
    end

    def self.snapshot_config
      current_config = {}

      PERSISTED_KEYS.each{|p_key|
        current_config[p_key] = Aromancer::Storage.instance.get_key(p_key)
      }

      current_config
    end

    def self.valid_config?(config)
      return false unless config.kind_of?(Hash)

      config.keys.all?{|k| PERSISTED_KEYS.include?(k.to_sym)}
    end

    def self.restore_config(config)
      return nil unless valid_config?(config)
      PERSISTED_KEYS.each{|p_key|
        Aromancer::Storage.instance.set_key(p_key, config[p_key])
      }
    end

    def self.recreate!
      current_config = snapshot_config
      FileUtils.rm_rf(storage_filepath)
      Aromancer::Storage.instance.reload!
      restore_config(current_config)
    end

    def self.storage_filepath
      filepath = File.join(Aromancer.home_directory, "v#{Aromancer::VERSION}.json")

      # create storage file if not present
      unless File.exist?(filepath)
        File.open(filepath, "w+") do |f|
          f.write({created_at: Time.now}.to_json)
        end
      else

      end

      filepath
    end

    def self.get_last_error_timestamp
      e = get_last_error
      if e && e["created_at"]
        return Time.parse(e["created_at"]).to_i
      end

      return Time.now.to_i
    end

    def self.get_preference(preference, default: nil)
      p_key = "preference_#{preference}"
      pref = Aromancer::Storage.instance.get_key(p_key)
      if pref.nil? && !default.nil?
        Aromancer::Storage.instance.set_key(p_key, default)
        pref = Aromancer::Storage.instance.get_key(p_key)
      end
      pref
    end

    def self.set_preference(preference, value)
      p_key = "preference_#{preference}"
      Aromancer::Storage.instance.set_key(p_key, value)
    end

    def self.toggle_preference(key)
      v = get_preference(key, default: DEFAULT_PREFERENCES["preference_#{key}"])
      set_preference(key, !v)
    end

    def self.toggle_force_ssl
      toggle_preference(:force_ssl)
      v = get_preference(:force_ssl)
      Aromancer::Storage.set_key(:server_url_scheme, "http#{v ? :s : ""}")
      Aromancer::Storage.set_key(:websocket_scheme, "ws#{v ? :s : ""}")
    end

    def self.set_signed_out_flag(flag)
      instance.set_key(:signed_out_flag, flag)
    end

    def self.get_signed_out_flag
      Aromancer::Storage.instance.get_key(:signed_out_flag)
    end

    def self.set_player(player_hash)
      instance.set_key(:player, player_hash)
    end

    def self.get_player
      Aromancer::Storage.instance.get_key(:player)
    end

    def self.set_legends(legends_array)
      instance.set_key(:legends, legends_array)
    end

    def self.get_legends
      Aromancer::Storage.instance.get_key(:legends)
    end

    def self.set_arena(arena_hash)
      instance.set_key(:arena, arena_hash)
      Aromancer::UnixDom.render_arena
    end

    def self.get_arena
      Aromancer::Storage.instance.get_key(:arena)
    end

    def self.set_stream(stream_array)
      instance.set_key(:stream, stream_array)
    end

    def self.get_stream
      Aromancer::Storage.instance.get_key(:stream)
    end

    def self.set_last_error(error_hash)
      instance.set_key(:last_error, error_hash)
    end

    def self.get_last_error
      Aromancer::Storage.instance.get_key(:last_error)
    end

    def self.set_server_url(server_url)
      uri = URI.parse(server_url)
      if uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS)
        URI_KEYS.each{|k|
          instance.set_key("server_url_#{k}", uri.select(k).first)
        }
      elsif get_server_url.nil?
        set_server_url(DEFAULT_SERVER_URL)
      end
    end

    def self.get_server_url
      set_server_url(DEFAULT_SERVER_URL) if URI_KEYS.all?{|k| Aromancer::Storage.instance.get_key("server_url_#{k}").nil?}
      URI.parse(URI_KEYS.map{|k|
        c = Aromancer::Storage.instance.get_key("server_url_#{k}")
        case k
        when :scheme
          "#{c}://"
        when :host
          c
        when :port
          ":#{c}"
        end
      }.join("")).to_s
    end

    def self.get_websocket_url
      # default scheme is ws
      w_scheme = Aromancer::Storage.instance.get_key(:websocket_scheme)
      instance.set_key(:websocket_scheme, :ws) if w_scheme.nil?
      w_scheme = Aromancer::Storage.instance.get_key(:websocket_scheme)

      # default path is broadcast
      w_path = Aromancer::Storage.instance.get_key(:websocket_path)
      instance.set_key(:websocket_path, :broadcast) if w_path.nil?
      w_path = Aromancer::Storage.instance.get_key(:websocket_path)

      # asserts host and port not nil
      # assumes same-as-server host and port for now
      host = Aromancer::Storage.instance.get_key(:server_url_host)
      port = Aromancer::Storage.instance.get_key(:server_url_port)

      URI.parse("#{w_scheme}://#{host}:#{port}/#{w_path}").to_s
    end

    def get_key(key)
      Aromancer::Cli.instance.storage_mutex.synchronize do
        key = key.to_s

        # ensure default for key exists
        @cache[key] = {value: nil, persisted: false} unless @cache.keys.include?(key)
        if false && (@cache[:preference_debug.to_s] || {value: DEFAULT_PREFERENCES[:preference_debug]})[:value]
          Aromancer::Prompt.say("#{__method__} > @cache[#{key}]=#{@cache[key]}")
        end
        # return cache value if storage open or the cache value is persisted
        return @cache[key][:value] if @storage_open || @cache[key][:persisted]

        # open storage
        @storage_open = true
        storage_contents = {}
        begin
          @parser_error = nil
          # read storage
          storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath, encoding: "UTF-8"))
        rescue StandardError => e
          @storage_open = false
          if @parser_error.nil?
            @parser_error = e
            return get_key(key)
          else
            raise @parser_error
          end
        end

        # only update the cache value if present in storage
        if storage_contents.keys.include?(key)
          @cache[key] = {value: storage_contents[key], persisted: true}
        else
          @cache[key][:persisted] = false
        end

        value = @cache[key][:value]
        @storage_open = false
        clear_cache! if @clear_flag
        return value
      end
    end

    def set_key(key, value)
      Aromancer::Cli.instance.storage_mutex.synchronize do
        key = key.to_s

        # ensure default for key exists
        @cache[key] = {value: value, persisted: false} unless @cache.keys.include?(key)

        # assign new cache value and set persisted to false
        @cache[key][:value] = value
        @cache[key][:persisted] = false

        if @storage_open && (@cache[:preference_debug.to_s] || {value: DEFAULT_PREFERENCES[:preference_debug]})[:value]
          Aromancer::Prompt.say("#{__method__} > @cache[#{key}]=#{@cache[key]}")
        end
        # return if storage open
        # non-persisted cache values update next cycle
        return if @storage_open

        # open storage
        @storage_open = true
        storage_contents = {}
        begin
          @parser_error = nil
          # read storage
          storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath, encoding: "UTF-8"))
        rescue StandardError => e
          @storage_open = false
          if @parser_error.nil?
            @parser_error = e
            return get_key(key)
          else
            raise @parser_error
          end
        end

        # update storage and cache
        ([key] + @cache.keys.select{|k|
          !@cache[k][:persisted]
        }).each{|k|
          storage_contents[k] = @cache[k][:value]
          @cache[k][:persisted] = true
        }

        # write storage
        File.open(Aromancer::Storage.storage_filepath, "w+") do |f|
          f.write(storage_contents.to_json)
        end

        if (@cache[:preference_debug.to_s] || {value: DEFAULT_PREFERENCES[:preference_debug]})[:value]
          Aromancer::Prompt.say("#{__method__} > @cache[#{key}]=#{@cache[key]}")
        end

        # close storage
        @storage_open = false
        clear_cache! if @clear_flag
      end
    end
  end
end
