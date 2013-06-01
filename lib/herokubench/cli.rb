require "digest/sha1"
require "heroku/auth"
require "heroku/command"
require "heroku/command/base"
require "heroku/command/help"
require "heroku/plugin"
require "thor"
require "tmpdir"
require "uri"
require "herokubench"
require "yaml"

class HerokuBench::CLI < Thor

  desc "create APP_NAME", <<-DESC
create a bench-server on Heroku

  DESC

  def create(name)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "heroku create #{name} -s cedar --buildpack https://github.com/ddollar/heroku-buildpack-multi.git"
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
        system "git add . >" + null_dev
        system "git commit -m commit >" + null_dev
        system "git push heroku -f master"
        heroku "config:add LD_LIBRARY_PATH=/app/vendor/apache-2.4.4/lib/:$LD_LIBRARY_PATH BUILDPACK_URL=https://github.com/ddollar/heroku-buildpack-multi.git"
        # heroku "config:set PATH=/app/vendor/apache-2.4.4/bin/:$PATH"
      end
    end
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
