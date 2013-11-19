$:.unshift File.expand_path("../lib", __FILE__)
require "herokubench/version"

Gem::Specification.new do |gem|
  gem.name    = "herokubench"
  gem.version = HerokuBench::VERSION

  gem.author      = "Cory Dolphin"
  gem.email       = "wcdolphin@gmail.com"
  gem.homepage    = "http://corydolphin.com/herokubench"
  gem.summary     = "A gem to help load testing web applications deployed on AWS or Heroku, using apache-bench"
  gem.description = <<-EOF
      Make it rain on the cloud.

      Herokubench allows you to easily load test websites, from the cloud, for free. Use hundreds of free dynos on Heroku to run apache-bench, in the same way you would run it locally.

      Confused? Checkout `hbench help`
  EOF
  gem.executables = ["hbench", "herokubench"]
  gem.license     = "MIT"
  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|server/|spec/|test/)} }

  gem.add_dependency "heroku",         ">= 2.26.0", "< 3.0"
  gem.add_dependency "thor",           "~> 0.18.1"
  gem.add_dependency "ruby-progressbar",">= 1.2.0"

  gem.post_install_message = "Please run 'hbench create' to create your bench-server."
end
