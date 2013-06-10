$:.unshift File.expand_path("../lib", __FILE__)
require "herokubench/version"

Gem::Specification.new do |gem|
  gem.name    = "herokubench"
  gem.version = HerokuBench::VERSION

  gem.author      = "Cory Dolphin"
  gem.email       = "wcdolphin@gmail.com"
  gem.homepage    = "https://github.com/wcdolphin/heroku-bench"
  gem.summary     = "A gem to help load testing web applications deployed on AWS or Heroku, using apache-bench"
  gem.description = <<-EOF
      Make it rain on the cloud.

      herokubench, or hbench for short, is a simple gem which eanbles you to easily load test websites, 
      using a server hosted by Heroku (on AWS). The gem manages deploying
      an app with no running dynos (free), and abuses the concept of one-off
      jobs to run the Apache Benchmark, ab. 

  EOF
  gem.executables = "hb"

  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|server/|spec/|test/)} }

  gem.add_dependency "heroku",         ">= 2.26.0", "< 3.0"
  gem.add_dependency "thor",           "~> 0.18.1"


  gem.post_install_message = "Please run 'hbench create' to create your bench-server."
end
