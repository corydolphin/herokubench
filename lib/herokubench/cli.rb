require "digest/sha1"
require "heroku/auth"
require "heroku/command"
require "heroku/command/base"
require "heroku/command/help"
require "heroku/cli"
require "heroku/plugin"
require "thor"
require "tmpdir"
require "uri"
require "herokubench"
require "yaml"
require "pathname"

class HerokuBench::CLI < Thor

  desc "create APP_NAME", <<-DESC
create a bench-server on Heroku

  DESC

  def create(name)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "heroku create #{name} -s cedar --buildpack https://github.com/wcdolphin/heroku-buildpack-apache.git"
      end
    end
    write_config :app => name, :host => "#{name}.herokuapp.com"
    update
  end


  desc "update", <<-DESC
update the bench-server

  DESC

  def update
    error "no app yet, create first" unless config[:app]

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "git init"
        system "git remote add origin git@github.com:wcdolphin/heroku-benchserver.git"
        system "git remote add heroku git@#{heroku_git_domain}:#{config[:app]}.git"
        system "git pull origin master >" + null_dev
        # system "git add . >" + null_dev
        # system "git commit -m commit >" + null_dev
        system "git push heroku -f master >" +  null_dev
        # heroku "config:add LD_LIBRARY_PATH=/app/vendor/apache-2.4.4/lib/:$LD_LIBRARY_PATH BUILDPACK_URL=https://github.com/ddollar/heroku-buildpack-multi.git"
        # heroku "config:set PATH=/app/vendor/apache-2.4.4/bin/:$PATH"
      end
    end
  end

  desc "bench site", "bench the bench-server"
  method_option :concurrency , :aliases => "-c", :default => 1000, :desc => "Number of multiple requests to perform at a time. Default is one request at a time."
  method_option :requests , :aliases => "-n", :default => 10000, :desc => "Number of requests to perform for the benchmarking session"
  method_option :instances, :alias => "-i", :default => 2, :desc => "Number of instances to run simultaneously, default is 1"
  def bench(site, c=1000, n=10000, i=1)
    error "no app yet, create first" unless config[:app]


    Heroku.user_agent = "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
    Heroku::Command.load
    Heroku::Command.run("run", ["ab -c #{options[:concurrency]} -n #{options[:requests]} #{site}", "--app", "#{config[:app]}"])


    # Heroku.user_agent = "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
    # Heroku::Command.load
    # Heroku::Command.run("run", ["ab -c #{c} -n #{n} #{site}", "--app", "#{config[:app]}"])

    # Heroku::CLI.start("run", "ab -c 1000 -n 1000 http://www.google.com/", "--app", "#{config[:app]}")

  end

   desc "hello NAMES", "long desc"
    def hello(*names)
        puts "hello #{names.join('; ')}"
    end

private
 
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
