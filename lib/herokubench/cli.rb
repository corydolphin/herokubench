require "digest/sha1"
require "heroku/auth"
require "heroku/command"
require "heroku/command/base"
require "heroku/command/help"
require "heroku/command/apps"
require "heroku/cli"
require "heroku/plugin"
require "thor"
require "tmpdir"
require "uri"
require "herokubench"
require "yaml"
require "pathname"
require "stringio"
require 'tempfile'

# This class is based upon Vulcan, and copies heavily.

class HerokuBench::CLI < Thor
  class_option "verbose",  :type => :boolean
  check_unknown_options!  :except => [:ab, :multi]
  default_task :ab


  class_options["verbose"] = false if class_options["verbose"].nil?
  Heroku.user_agent = "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
  Heroku::Command.load
  

  desc "create APP_NAME", "Create your personal bench-server on Heroku"
  def create(name="")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do

        args = ["#{name}", "-s","cedar", "--buildpack","https://github.com/wcdolphin/heroku-buildpack-apache.git"]
        args.delete("")
        result = capture { Heroku::Command.run("create", args) }
        name = /\s(.+)\.\.\./.match(result).captures[0]
        puts "Created your personal benchserver: #{name}"
      end
    end
    write_config :app => name, :host => "#{name}.herokuapp.com"
    update
  end


  desc "ab URL", "Run apache-bench, using a single, one-off Heroku dyno"
  def ab(*args)
    error "no app yet, please create first" unless config[:app]
    puts "Running one-off dyno, please be patient"
    Heroku::Command.run("run", ["ab #{args.join(' ')}", "--app", "#{config[:app]}"])
  end




  desc "multi URL", "Run apache-bench, using multiple one-off dynos"
  def multi(dynos, *args)
    error "no app yet, create first" unless config[:app]
    puts "In order to use multi, you must specify the number " \
          "of one-off dynos to use concurrently. \n\tExample usage: "\
          "\n \thb multi 5 -c 1000 -n 10000 http://www.google.com/"

    bencher_path = File.expand_path("../bencher.rb",__FILE__)

    dynos = dynos.to_i
    results = Array.new(dynos)
    n = 0

    ab_command = "ab #{args.join(' ')}"


    until n == dynos do
      puts "Starting Instance##{n+1} of #{dynos}"
      results[n] = Tempfile.new("hbench_out #{n}")

      spawn( "ruby #{bencher_path} \"#{ab_command} \" --app #{config[:app]}", :out=>results[n].path)
      n = n + 1
    end

    Process.waitall

    results.each do |f| 
      puts f.path
      puts f.read
      f.close
      f.unlink
    end


  end

private

  def update
    error "no app yet, create first" unless config[:app]

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "git init -q"
        system "git remote add origin git@github.com:wcdolphin/heroku-benchserver.git"
        system "git remote add heroku git@#{heroku_git_domain}:#{config[:app]}.git"
        pullres = capture { system "git pull --quiet origin master"}
        pushres = capture { system "git push heroku master --quiet"}
      end
    end
  end

  def capture
    results = $stdout = StringIO.new
    yield
    $stdout = STDOUT
    results.close_write
    results.rewind
    return results.read
  end



 #Yeah, we are windows compatible. Because you should be too.
 def null_dev
    return test(?e, '/dev/null') ? '/dev/null' : 'NUL:'
  end

  def action(message)
    print "#{message}... "
    yield
    puts "done"
  end

  def heroku(command)
    %x{ env BUNDLE_GEMFILE= heroku #{command} 2>&1 }
  end

  def config_file
    File.expand_path("~/.herokubench")
  end

  def config
    read_config
  end

  def read_config
    return {} unless File.exists?(config_file)
    config = YAML.load_file(config_file)
    config.is_a?(Hash) ? config : {}
  end

  def write_config(config)
    full_config = read_config.merge(config)
    File.open(config_file, "w") do |file|
      file.puts YAML.dump(full_config)
    end
  end

  def error(message)
    puts "!! #{message}"
    exit 1
  end

  def server_path
    File.expand_path("../../../server", __FILE__)
  end

  #
  # heroku_git_domain checks to see if the heroku-accounts plugin is present,
  # and if so, it will set the domain to the one that matches the credentials
  # for the currently set account
  #
  def heroku_git_domain
    suffix = %x{ git config heroku.account }
    suffix = "com" if suffix.nil? or suffix.strip == ""
    "heroku.#{suffix.strip}"
  end

end
