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


  desc "ab [options] [http[s]://]hostname[:port]/path", "Run apache-bench using a single one-off dyno"
  long_desc <<-LONGDESC
  'hb ab' will run apache-bench, using a one-off dyno on Heroku in order
  to best benchmark the performance of your webservice.

  For more information, run `hb ab help`

  > $ hb ab -c 100 -n 1000 http://www.google.com
  LONGDESC

  def ab(*args)
    puts config[:app]
    error "no app yet, please create first" unless config[:app]
    puts "Running one-off dyno, please be patient"
    Heroku::Command.run("run", ["ab #{args.join(' ')}", "--app", "#{config[:app]}"])
  end


  desc "multi NUMBER [options] [http[s]://]hostname[:port]/path", "Run apache-bench, using multiple one-off dynos"
  long_desc <<-LONGDESC
  'hb multi' will run apache-bench, using multiple one-off dynos in order
  to incrase the throughput of your benchmark.

  The arguments are identical to that of 'hb ab' with the addition
  of the 'NUMBER' argument, representing the number of one-off dynos
  to execute your benchmark on.

  > $ hb multi 5 http://www.google.com
  LONGDESC
  def multi(dynos, *args)
    error "no app yet, create first" unless config[:app]
    error "Number of dynos must be an integer greater than 1" unless dynos.to_i >= 1
    begin
      num_requests = args[args.index("-n") + 1].to_i #hack to extract number of requests from the ab arguments.

      bencher_path = File.expand_path("../bencher.rb",__FILE__)

      numdynos = dynos.to_i
      results = []
      running_procs = {}
      progesses = {}
      ab_command = "ab #{args.join(' ')}"

      p_bar = ProgressBar.create(:title=>'Benching',:total=>numdynos*num_requests, :smoothing => 0.6)

      numdynos.times do  |n|
        t_file = Tempfile.new("hbench_out_#{n}") 
        pid = spawn( "ruby #{bencher_path} \"#{ab_command} \" --app #{config[:app]}", :out=>t_file.path, :err=>null_dev)
        running_procs[pid] = t_file
        progesses[pid] = 0
        puts t_file.path
      end


      until running_procs.empty?
        begin
          complete_results = Timeout.timeout(1) do
            pid = Process.wait
            results.push running_procs.delete(pid)
            p_bar.progress += num_requests - progesses[pid]
            progesses[pid] = num_requests
          end
        rescue Timeout::Error
          running_procs.each do |pid, tfile|
            progress = get_progress(tfile)
            p_bar.progress += progress - progesses[pid]
            progesses[pid] = progress
          end
        end
      end
      
      summary_result  = ApacheBenchSummaryResult.new

      puts results
      results.each  do |tfile|
        summary_result.add_result(ApacheBenchResult.new(tfile))
      end 
      puts summary_result.get_summary_result()


    rescue Interrupt
      print "\nExiting...Please be patient"
      running_procs.keys.each do |pid|
        Process.kill("INT", pid)
        print "."
      end
      print "done.\n"
    rescue => exception
      say("HerokuBench ran into an unexpected exception. Please contact @wcdolphin",:red)
      say(exception,:red)
      puts exception.backtrace
    end
  end

  private

  # Attemptes to parse a value as a Float or integer, defaulting to the original
  # string if unsuccesful.
  def parse(v)
    ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
  end

  # pretty much the opposite of parse. Returns a string of the best way
  # to represent a float, int or string value
  def serialize(v)
    ((float = v.round(1)) && (float % 1.0 == 0) ? float.to_i.to_s : float.to_s) rescue v.to_s
  end

  def get_progress(tfile)
    tfile.rewind

    progress = tfile.each_line.collect do |line|
      group = line.scan(/Completed (\d+) requests/)
      group = group.empty? ? 0 : group[0][0]
    end
    progress = progress.last.to_i
  end
  # def summarize(results)
  #   summary = {}

  #   results.each do |result|
  #     result.each do |type, hash|
  #       summary[type] = {} if summary[type].nil?
  #       hash.each do |k,v|
  #         summary[type][k] = [0.0] * v.length if summary[type][k].nil?
  #         v.each_index do |i|
  #           if not @@summable_fields.index(k).nil?
  #             summary[type][k][i] += v[i]
  #           elsif not @@medianable_fields.index(k).nil?
  #             summary[type][k][i] += v[i] / results.length.to_f
  #           elsif not @@maxable_fields.index(k).nil?
  #             summary[type][k][i] = [v[i], summary[type][k][i]].max
  #           else
  #             summary[type][k][i] = v[i]
  #           end
  #         end
  #       end
  #     end
  #   end

  #   say "\tCumulative results, summed across dynos"
  #   say ""
  #   summary[:generic_result].each{|k,v| say format(k+":",v, 25)}

  #   say ""
  #   say "\t Connection Times (ms), median across dynos"
  #   say format("",["min", "mean", "[+/-sd]" ,"median","max"],15)
  #   summary[:connection_times].each{|k,v| say format(k+":",v, 15)}

  #   say ""
  #   say "\t Percentage of the requests served within a certain time (ms)"
  #   say "\t across dynos"
  #   summary[:response_time_cdf].each{|k,v| say format(k+"",v, 15)}
  # end

  def format(k,v, pad)
    "#{fill(k,pad)}#{v.map{|val| fill(serialize val)}.join('')}\r\n"
  end

  def fill(str, length=12)
    "#{str}#{" " * (length - str.length)}"
  end

  def get_result_hash(f)
    result_hash = {}
    f.each_line do |line|
      @@result_type.each do |k,v|
        group = line.scan(v)
        if not group.nil? and group.length.equal? 1
          capture = group[0].map {|v| parse v} #convert to float/int/etc
          result_hash[k] = {} unless result_hash.has_key?(k)
          res_key = capture[0]
          res_values = capture.slice(1, capture.length)
          result_hash[k][res_key] = res_values
        end
      end
    end
    result_hash
  end

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
