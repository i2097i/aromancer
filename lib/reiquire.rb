=begin

  reiquire.rb

  ruby require helpers.

  by i2097i

=end

# dependencies
require :"active_support/all".to_s
require :i18n.to_s
require :faraday.to_s
require :fileutils.to_s
require :"websocket-client-simple".to_s

# require :"tty-box".to_s # draw box shapes
# require :"tty-color".to_s # detect color support
require :"tty-cursor".to_s # cursor support
require :"tty-font".to_s # large stylized text
require :"tty-table".to_s # render tables
require :"tty-prompt".to_s # main user interaction
# require :"tty-reader".to_s # more granular user input
require :"tty-screen".to_s # detect screen dimensions

module Reiquire
  GEM_PATH = Gem.loaded_specs[:aromancer.to_s]&.full_gem_path

  def self.aromancer
    # configure I18n

    I18n.load_path += Dir["#{Reiquire::GEM_PATH}/locale/*.yml"]
    I18n.available_locales = [:en]
    I18n.default_locale = :en

    # require sys folders
    Reiquire::requires([:aromancer])
  end

  def self.requires(dirs)
    dirs.each{|d|
      Dir[
        File.join(__dir__, d.to_s, :"**/*.rb".to_s)
      ].each { |f| require f}
    }
  end
end