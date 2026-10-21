# frozen_string_literal: true

=begin

  serve.rb

  aromancer serve functionality.

  by i2097i

=end

module Aromancer
  class Serve
    SERVER_NAME = :"#{Aromancer.to_s.downcase}_serve".to_s

    def self.run
      unless Dir.exist?(serve_dir)
        system(:"git clone git@github.com:arowmancy/#{SERVER_NAME}.git #{serve_dir}".to_s)
      end
      FileUtils.chdir serve_dir do
        branch = "v#{Aromancer::VERSION}"
        system(:"git checkout #{branch}".to_s)
        system(:"git pull origin #{branch}".to_s)
        system(:"bin/setup".to_s)
      end
    end

    private

    def self.serve_dir
      File.join(Aromancer.home_directory, SERVER_NAME)
    end
  end
end
