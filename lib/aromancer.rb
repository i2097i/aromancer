# frozen_string_literal: true

=begin

  aromancer.rb

  aromancer.

  by i2097i

=end

require_relative :reiquire.to_s
Reiquire::aromancer

module Aromancer
  FONT = TTY::Font.new(:standard)

  def self.get_font(text = :aromancer.to_s, letter_spacing = 1)
    Aromancer::FONT.write(text, letter_spacing: letter_spacing).split("\n")
  end

  def self.home_directory
    "#{`echo $HOME`.strip}/.aromancer"
  end

  def self.print_last_error(i18n_key = nil)
    last_error = Aromancer::Storage.get_last_error
    return if last_error.nil?
    last_error = last_error.symbolize_keys
    message = last_error[:body]
    begin
      message = JSON.parse(message).symbolize_keys
      message = message[:error_message] if message.keys.include?(:error_message)
    rescue JSON::ParserError => e
      message = last_error[:body]
    end
    Aromancer::Prompt.say(I18n.t(i18n_key, status: last_error[:status], error: message))
  end
end
