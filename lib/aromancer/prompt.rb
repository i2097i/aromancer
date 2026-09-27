# frozen_string_literal: true

=begin

  prompt.rb

  tty-prompt gem wrapper.

  by i2097i

=end

module Aromancer
  class Prompt
    include Singleton

    attr_accessor :prompt

    def initialize
      self.prompt = TTY::Prompt.new
    end

    def self.p
      Aromancer::Prompt.instance.prompt
    end

    def self.say(message)
      (message.kind_of?(String) ? message.split("\n").each{|l| p.say(l.to_s.center(TTY::Screen.width))} : message)
    end
  end

end
