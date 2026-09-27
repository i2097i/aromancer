=begin

  storage.rb

  json data store

  by i2097i

=end

module Aromancer
  class Storage
    include Singleton

    def initialize
      FileUtils.mkdir_p(Aromancer.home_directory)
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

    def get_key(key)
      storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath))
      if storage_contents.keys.include?(key.to_s)
        return storage_contents[key.to_s]
      end
    end

    def set_key(key, value)
      storage_contents = JSON.parse(File.read(Aromancer::Storage.storage_filepath))
      storage_contents[key.to_s] = value

      File.open(Aromancer::Storage.storage_filepath, "w+") do |f|
        f.write(storage_contents.to_json)
      end
    end
  end
end
