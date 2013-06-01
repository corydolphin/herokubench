$:.unshift File.expand_path("../lib", __FILE__)
require "herokubench/version"

Gem::Specification.new do |gem|
  gem.name    = "herokubench"
  gem.version = HerokuBench::VERSION

  gem.author      = "Cory Dolphin"
  gem.email       = "wcdolphin@gmail.com"
  gem.homepage    = "https://github.com/wcdolphin/heroku-bench"
  gem.summary     = "Make it rain on your cloud."
  gem.description = gem.summary
  gem.executables = "hbench"

  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|server/|spec/|test/)} }

  gem.add_dependency "heroku",         ">= 2.26.0", "< 3.0"
  gem.add_dependency "thor",           "~> 0.14.6"

  gem.post_install_message = "Please run 'hbench update' to update your build server."
end
