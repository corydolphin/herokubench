$:.unshift File.expand_path("../../lib", __FILE__)
require "thor"
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


class BaseResult < Thor
	@@summable_fields = []
	@@maxable_fields = []
end

class ApacheBenchResult < BaseResult

    attr_accessor :result_tfile
    @@result_regexes = {
      :connection_times=>/(.+):\s+\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)/,
      :generic_result=> /^([\w\s]+):\s*([\d|\.]+)/,
      :response_time_cdf=>/(\d+%)\s+(\d+)/
    }
    @@summable_fields = ["Complete requests","Failed requests", "Write errors", "Requests per second", "Total transferred", "HTML transferred", "Concurrency Level"]
    @@averageable_fields = ["Connect", "Processing", "Waiting", "Total", "Time per request", "Time taken for tests"]
    @@maxable_fields    = ["50%", "66%", "75%", "80%", "90%", "95%", "98%", "99%","100%"]

  no_commands do
  	def initialize(temp_file)
      @result_tfile = temp_file
  	end

  	def result_hash()
      @result_tfile.rewind
      resulting_hash = {}
      @result_tfile.each_line do |line|
        @@result_regexes.each do |type,v|
          group = line.scan(v)
          if not group.nil? and group.length.equal? 1
            capture = group[0].map {|v| parse v} #convert to float/int/etc
            res_key = capture[0]
            res_values = capture.slice(1, capture.length)

            resulting_hash[type] = {} unless resulting_hash.has_key? type
            resulting_hash[type][res_key] = res_values.length == 1 ? res_values.first : res_values  
            break
          end
        end
       end
       resulting_hash
  	end
  end
end

class ApacheBenchSummaryResult < ApacheBenchResult
	no_commands do
		def initialize()
			@results = []
		end

		def add_result(ab_result)
			@results.push ab_result
		end

		def get_summary_result()
			summary_result_hash = {}
			@results.each do |result|
				result.result_hash.each do |result_type, res_type_hashes| 
					summary_result_hash[result_type] = {} unless summary_result_hash.has_key? result_type
					res_type_hashes.each do |result_key, value|
						summary_result_hash[result_type][result_key] = [] unless summary_result_hash[result_type].has_key? result_key
						summary_result_hash[result_type][result_key].push value
					end
				end	
			end

			summary_result_hash.each do |result_type, result_hash|
				result_hash.each do |result_name, result_values| 
					if @@summable_fields.include? result_name
						summary_result_hash[result_type][result_name] = result_values.inject(:+)			
					elsif @@averageable_fields.include? result_name
						summary_result_hash[result_type][result_name] = deep_average(result_values)
					elsif  @@maxable_fields.include? result_name
						summary_result_hash[result_type][result_name] = result_values.max
					else
						summary_result_hash[result_type][result_name] = result_values.first
					end
				end
			end

			summary_result_hash
		end

		def print
			summary = self.get_summary_result()
			if summary.empty?
				say("Herokubench ran into an error while executing ApacheBench. It is likely there was a syntax error in your command. Please see output below.", :red)
				@results.first.result_tfile.rewind
				@results.first.result_tfile.each_line do |line|
					puts line
				end
				return
			end
			say("Cumulative results, summed across dynos",:bold) 
			summary[:generic_result].each{|k,v| printf "%-20s %s\n", k + ":",v}

      say ""
      say("Connection Times (ms), median across dynos",:bold)
			printf "%-20s %-8s %-8s %-8s %s\n", "","min", "mean", "[+/-sd]" ,"median","max"
			summary[:connection_times].each do |k,v|
				printf "%-20s %-8s %-8s %-8s %s\n",k +":", v[0], v[1], v[2], v[3], v[4], v[5]
			end

      say ""
			say("Percentage of the requests served within a certain time (ms) across dynos", :bold)
			summary[:response_time_cdf].each{|k,v| printf "  %-20s %s\n", k,v}

		end
	end
end



private

def parse(v)
  ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
end

def deep_average(arr)
	result = []
	if not arr.empty? and arr[0].is_a? Array #we need to do a 'deep' average.
		arr[0].each_index do |i|
			result[i] = arr.collect {|a| a[i]/arr.length.to_f}.inject(:+)
		end
		result
	else	
		arr.collect {|a| a/arr.length}.inject(:+)
	end
end



