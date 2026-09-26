# frozen_string_literal: true

=begin

  aromancer.gemspec

  aromancer gem specification.

  by i2097i

=end

require_relative "lib/aromancer/version"

Gem::Specification.new do |spec|
  spec.name = "aromancer"
  spec.version = Aromancer::VERSION
  spec.authors = ["i2097i"]
  spec.email = ["i2097i@hotmail.com"]

  spec.description   = ""
  spec.summary       = ""
  spec.homepage      = "https://github.com/i2097i/aro"
  spec.license       = "MIT"
  spec.files         = `git ls-files`.split("\n").reject{|p| p.match?(/^(spec|.release|.*.gem$)/)}
  spec.bindir        = "bin"
  spec.executables   = ["aromancer"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 4.0.7"

  # development gems
  spec.add_development_dependency "irb", "~> 1.18"
  spec.add_development_dependency "bundler", "~> 4.0.21"
  spec.add_development_dependency "listen", "~> 3.10"
  spec.add_development_dependency "rake", "~> 13.4.2"
  spec.add_development_dependency "rspec", "~> 3.13.2"

  # runtime gems
  spec.add_runtime_dependency     "i18n", "~> 1.15.2"
  spec.add_runtime_dependency     "faraday", "~> 2.14.4"
  spec.add_runtime_dependency     "sqlite3", "~> 2.9.6"
  spec.add_runtime_dependency     "activerecord", "~> 8.1.4"
  spec.add_runtime_dependency     "websocket-client-simple", "~> 0.9.0"

  spec.add_runtime_dependency     "tty-box", "~> 0.7.0"
  spec.add_runtime_dependency     "tty-color", "~> 0.6.0"
  spec.add_runtime_dependency     "tty-cursor", "~> 0.7.1"
  spec.add_runtime_dependency     "tty-font", "~> 0.5.0"
  spec.add_runtime_dependency     "tty-table", "~> 0.12.0"
  spec.add_runtime_dependency     "tty-prompt", "~> 0.23.1"
  spec.add_runtime_dependency     "tty-screen", "~> 0.8.2"
end
