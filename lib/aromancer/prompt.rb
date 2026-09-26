# frozen_string_literal: true

=begin

  aromancer.rb

  aromancer.

  by i2097i

=end

module Aromancer
  class P
    include Singleton

    attr_accessor :prompt

    def initialize
      self.prompt = TTY::Prompt.new
    end

    def self.p
      Aro::Prompt.instance.prompt
    end

    def self.say(message)
      p.say(message)
    end
  end

end
