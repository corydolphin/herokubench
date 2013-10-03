class BaseResult
	@@summable_fields = []
	@@maxable_fields = []


end

class ApacheBenchResult < BaseResult
  attr_accessor :result_hash
  @@result_regexes = {
    :connection_times=>/(.+):\s+\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)\s+([\d|\.]+)/,
    :generic_result=> /^([\w\s]+):\s*([\d|\.]+)/,
    :response_time_cdf=>/(\d+%)\s+(\d+)/
  }
  @@summable_fields = ["Complete requests","Failed requests", "Write errors", "Requests per second", "Total transferred", "HTML transferred", "Concurrency Level"]
  @@averageable_fields = ["Connect", "Processing", "Waiting", "Total", "Time per request"]
  @@maxable_fields    = ["50%", "66%", "75%", "80%", "90%", "95%", "98%", "99%","100%"]

	def initialize(temp_file)
		@result_hash = {}

		temp_file.each_line do |line|
		  @@result_regexes.each do |type,v|
		    group = line.scan(v)
		    if not group.nil? and group.length.equal? 1
		      capture = group[0].map {|v| parse v} #convert to float/int/etc
		      res_key = capture[0]
		      res_values = capture.slice(1, capture.length)

		      @result_hash[type] = {} unless @result_hash.has_key? type
		      @result_hash[type][res_key] = res_values.length == 1 ? res_values[0] : res_values  
		    end
		  end
		 end
		puts @result_hash
	end

end

class ApacheBenchSummaryResult < ApacheBenchResult

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
					result_hash[result_name] = result_values.inject(:+)			
				elsif @@averageable_fields.include? result_name
					result_hash[result_name] = deep_average result_values
				elsif  @@maxable_fields.include? result_name
					result_hash[result_name] = result_values.max
				else
					result_hash[result_name] = result_values.first
				end
			end
		end

		summary_result_hash		
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
			result[i] = arr.collect {|a| a[i]/arr.length}.inject(:+)
		end
		result
	else	
		arr.collect {|a| a/arr.length}.inject(:+)
	end
end



