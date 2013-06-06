#!/usr/bin/env ruby 

require "heroku/command"
require "heroku/command/base"
require "heroku/command/help"
require "heroku/command/apps"
require "heroku/cli"
require "heroku/plugin"

def capture
	results = $stdout = StringIO.new
	yield
	$stdout = STDOUT
	results.close_write
	results.rewind
	return results.read
end

Heroku.user_agent = "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
Heroku::Command.load
Heroku::Command.run("run", ARGV)

