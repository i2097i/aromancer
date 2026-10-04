=begin

  storage.rb

  json data store

  by i2097i

=end

module Aromancer
  class Storage
    include Singleton

    attr_accessor :storage_open, :cache

    def initialize
      clear_cache!
      FileUtils.mkdir_p(Aromancer.home_directory)
    end

    def clear_cache!
      @storage_open = false
      @cache = {}
    end

    def self.storage_filepath
      filepath = File.join(Aromancer.home_directory, "storage.json")

      # create storage file if not present
      unless File.exist?(filepath)
        File.open(filepath, "w+") do |f|
          f.write({version: Aromancer::VERSION, created: Time.now}.to_json)
        end
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

    def self.get_preference(preference, default: :default)
      p_key = "preference_#{preference}"
      p = instance.get_key(p_key)
      if p.nil?
        instance.set_key(p_key, default)
        return instance.get_key(p_key)
      end
      p
    end

    def self.set_preference(preference, value)
      p_key = "preference_#{preference}"
      instance.set_key(p_key, value)
    end

    def self.toggle_force_ssl
      set_preference(:force_ssl, !get_preference(:force_ssl))
      v = get_preference(:force_ssl)
      self.instance.set_key(:server_url_scheme, "http#{v ? :s : ""}")
      self.instance.set_key(:websocket_scheme, "ws#{v ? :s : ""}")
    end

    def self.set_signed_out_flag(flag)
      Aromancer::Storage.instance.set_key(:signed_out_flag, flag)
    end

    def self.get_signed_out_flag
      Aromancer::Storage.instance.get_key(:signed_out_flag)
    end

    def self.set_player(player_hash)
      Aromancer::Storage.instance.set_key(:player, player_hash)
    end

    def self.get_player
      Aromancer::Storage.instance.get_key(:player)
    end

    def self.set_legends(legends_array)
      Aromancer::Storage.instance.set_key(:legends, legends_array)
    end

    def self.get_legends
      Aromancer::Storage.instance.get_key(:legends)
    end

    def self.set_arena(arena_hash)
      Aromancer::Storage.instance.set_key(:arena, arena_hash)
    end

    def self.get_arena
      Aromancer::Storage.instance.get_key(:arena)
    end

    def self.set_stream(stream_array)
      Aromancer::Storage.instance.set_key(:stream, stream_array)
    end

    def self.get_stream
      Aromancer::Storage.instance.get_key(:stream)
    end

    def self.set_last_error(error_hash)
      Aromancer::Storage.instance.set_key(:last_error, error_hash)
    end

    def self.get_last_error
      Aromancer::Storage.instance.get_key(:last_error)
    end

    URI_KEYS = [
      :scheme,
      :host,
      :port
    ]

    def self.set_server_url(server_url)
      uri = URI.parse(server_url)
      if uri.kind_of?(URI::HTTP) or uri.kind_of?(URI::HTTPS)
        URI_KEYS.each{|k|
          Aromancer::Storage.instance.set_key("server_url_#{k}", uri.select(k).first)
        }
      else
        set_server_url(Aromancer::Server::DEVELOP_SERVER_URL)
      end
    end

    def self.get_server_url
      set_server_url(Aromancer::Server::DEVELOP_SERVER_URL) if URI_KEYS.all?{|k| Aromancer::Storage.instance.get_key("server_url_#{k}").nil?}
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
      Aromancer::Storage.instance.set_key(:websocket_scheme, :ws) if w_scheme.nil?
      w_scheme = Aromancer::Storage.instance.get_key(:websocket_scheme)

      # default path is broadcast
      w_path = Aromancer::Storage.instance.get_key(:websocket_path)
      Aromancer::Storage.instance.set_key(:websocket_path, :broadcast) if w_path.nil?
      w_path = Aromancer::Storage.instance.get_key(:websocket_path)

      # asserts host and port not nil
      # assumes same-as-server host and port for now
      host = Aromancer::Storage.instance.get_key(:server_url_host)
      port = Aromancer::Storage.instance.get_key(:server_url_port)

      URI.parse("#{w_scheme}://#{host}:#{port}/#{w_path}").to_s
    end

    def get_key(key)
      key = key.to_s

      # ensure default for key exists
      @cache[key] = {value: nil, persisted: false} unless @cache.keys.include?(key)

      # return cache value if storage open or the cache value is persisted
      return @cache[key][:value] if @storage_open || @cache[key][:persisted]

      # open storage
      @storage_open = true
      storage_contents = {}
      begin
        # read storage
        storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath))
      rescue StandardError => e
        @storage_open = false
        FileUtils.rm(Aromancer::Storage.storage_filepath)
        return
      end
      @storage_open = false

      # only update the cache value if present in storage
      if storage_contents.keys.include?(key)
        @cache[key][:value] = storage_contents[key]
        @cache[key][:persisted] = true
      else
        @cache[key][:persisted] = false
      end

      @cache[key][:value]
    end

    def set_key(key, value)
      key = key.to_s

      # ensure default for key exists
      @cache[key] = {value: nil, persisted: false} unless @cache.keys.include?(key)

      # assign new cache value and set persisted to false
      @cache[key][:value] = value
      @cache[key][:persisted] = false

      # return if storage open
      # non-persisted cache values update next cycle
      return if @storage_open

      # open storage
      @storage_open = true
      storage_contents = {}
      begin
        # read storage
        storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath))
      rescue StandardError => e
        @storage_open = false
        FileUtils.rm(Aromancer::Storage.storage_filepath)
        return
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

      # close storage
      @storage_open = false
    end
  end
end
