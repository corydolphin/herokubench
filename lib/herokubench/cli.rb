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
require 'ruby-progressbar'
$:.unshift File.expand_path("../../lib", __FILE__)
require 'herokubench/result'

# This class is based upon Vulcan, and copies heavily.

class HerokuBench::CLI < Thor
  class_option :verbose, :type => :boolean
  check_unknown_options!  :except => [:ab, :multi]
  default_task :ab
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

  desc "ab [options] [http[s]://]hostname[:port]/path", "Run apache-bench automatically spreading over dynos as necessary"
  long_desc <<-LONGDESC
  'hb ab' will run apache-bench, splitting the work between up between as many dynos as necessary, for a maximum of
  100 concurrent connections per dyno. The arguments are passed directly to ab.

  For more information, run `hb ab help`

  > $ hbench ab -c 100 -n 1000 http://www.google.com
  LONGDESC

  def ab(*args)
      num_requests_index = args.index("-n") #hack to extract number of requests from the ab arguments.
      concurrency_level_index = args.index("-c") #hack to extract number of requests from the ab arguments.
      unless concurrency_level_index.nil? or num_requests_index.nil? then
        num_requests = args[num_requests_index + 1].to_i
        concurrency_level = args[concurrency_level_index + 1].to_i

        num_dynos = (concurrency_level/100.0).ceil
        num_dynos = 1 if num_dynos ==0

        say "Inferred #{num_dynos} instances" if options[:verbose]
        args[args.index("-n") + 1] = (num_requests / num_dynos).to_i
        args[args.index("-c") + 1] = (concurrency_level / num_dynos).to_i
      end
      num_dynos ||= 1
      multi(num_dynos, *args)
  end

  desc "multi NUMDYNOS [options] [http[s]://]hostname[:port]/path", "Run apache-bench, using multiple one-off dynos"
  long_desc <<-LONGDESC
  'hbench multi' will run apache-bench, using a specfied number of dynos in order
  to incrase the throughput of your benchmark.

  The arguments are identical to that of 'hb ab' with the addition
  of the 'NUMDYNOS' argument, representing the number of one-off dynos
  to execute your benchmark on.

  > $ hbench multi 5 http://www.google.com
  LONGDESC
  def multi(dynos, *args)
    error "no app yet, create first" unless config[:app]
    error "Number of dynos must be an integer greater than 1" unless dynos.to_i >= 1

    begin
      say "Using #{config[:app]}" if options[:verbose] 
      say "Benching with #{dynos} dynos and arguments #{args}" if options[:verbose]

      bencher_path = File.expand_path("../bencher.rb",__FILE__)
      num_dynos = dynos.to_i

      running_procs = {}
      ab_command = "ab #{args.join(' ')}"

      p_bar = ProgressBar.create(:title=>'Benching',:total=>1 + num_dynos*100)
      summary_result  = ApacheBenchSummaryResult.new

      num_dynos.times do  |n|
        t_file = Tempfile.new("hbench_out_#{n}") 
        pid = spawn( "ruby #{bencher_path} \"#{ab_command} \" --app #{config[:app]}", :out=>t_file.path, :err=>null_dev)

        running_procs[pid] = t_file
        summary_result.add_result(ApacheBenchResult.new(t_file))
        puts t_file.path if options[:verbose]
      end


      until running_procs.empty?
        begin
          complete_results = Timeout.timeout(0.5) do
            pid = Process.wait
            running_procs.delete(pid)
          end
        rescue Timeout::Error
          diff = summary_result.get_progress() - p_bar.progress
          p_bar.progress+= diff
        end
      end

      p_bar.finish
      summary_result.print()

    rescue Interrupt
      say "Exiting...Please be patient"
      kill_running_procs(running_procs)
      kill_running_dynos()
      say "Done"
    rescue => exception
      say("HerokuBench ran into an unexpected exception. Please contact @wcdolphin",:red)

      begin
        kill_running_procs(running_procs)
        kill_running_dynos()
      rescue
      end #squelch exceptions when killing procs

      say(exception,:red)
      puts exception.backtrace
    end
  end



  desc "update", "Updates your remote bench server"
  def update
    error "No app yet, create first" unless config[:app]

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

  private


  def kill_running_procs(running_procs)
      print "Killing running processes"
      running_procs.keys.each do |pid|
        Process.kill("INT", pid)
        print "."
      end
  end

  def kill_running_dynos()
    print "\nKilling running dynos"
    result = capture { Heroku::Command.run("ps", ["--app", "#{config[:app]}"]) }
    result.split("\n").each do |line|
      dyno_name = line.scan(/(run.[\d]+)/)
      unless dyno_name.nil? or dyno_name.empty?
        capture {Heroku::Command.run("ps:stop", ["#{dyno_name[0][0]}","--app", "#{config[:app]}"])}
        print '.'
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
