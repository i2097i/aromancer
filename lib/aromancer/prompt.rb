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
      reload!
    end

    def reload!
      self.prompt = TTY::Prompt.new
    end

    def self.p
      Aromancer::Prompt.instance.prompt
    end

    def self.print_divider(text = nil)
      puts "\n" if TTY::Screen.width > 99.9
      self.p.say((text || "").center(TTY::Screen.width / 2.2, "-").center(TTY::Screen.width))
      puts "\n" if TTY::Screen.width > 99.9
    end

    def self.say(message, ljust: false, rjust: false)
      center = !ljust && !rjust
      if message.kind_of?(String)
        # puts "\n" if TTY::Screen.width > 99.9
        message.split("\n").each{|l|
          self.p.say(l.to_s.ljust(TTY::Screen.width)) if ljust
          self.p.say(l.to_s.center(TTY::Screen.width)) if center
          self.p.say(l.to_s.rjust(TTY::Screen.width)) if rjust
        }
      else
        self.p.say(message)
      end
    end
  end

end
