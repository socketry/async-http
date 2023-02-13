# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require_relative 'writable'

require 'async/clock'

module Async
	module HTTP
		module Body
			# A dynamic body which you can write to and read from.
			class Slowloris < Writable
				class ThroughputError < StandardError
					def initialize(throughput, minimum_throughput, time_since_last_write)
						super("Slow write: #{throughput.round(1)}bytes/s less than required #{minimum_throughput.round}bytes/s.")
					end
				end
				
				# In order for this implementation to work correctly, you need to use a LimitedQueue.
				# @param minimum_throughput [Integer] the minimum bytes per second otherwise this body will be forcefully closed.
				def initialize(*arguments, minimum_throughput: 1024, **options)
					super(*arguments, **options)
					
					@minimum_throughput = minimum_throughput
					
					@last_write_at = nil
					@last_chunk_size = nil
				end
				
				attr :minimum_throughput
				
				# If #read is called regularly to maintain throughput, that is good. If #read is not called, that is a problem. Throughput is dependent on data being available, from #write, so it doesn't seem particularly problimatic to do this check in #write.
				def write(chunk)
					if @last_chunk_size
						time_since_last_write = Async::Clock.now - @last_write_at
						throughput = @last_chunk_size / time_since_last_write
						
						if throughput < @minimum_throughput
							error = ThroughputError.new(throughput, @minimum_throughput, time_since_last_write)
							
							self.close(error)
						end
					end
					
					super.tap do
						@last_write_at = Async::Clock.now
						@last_chunk_size = chunk&.bytesize
					end
				end
			end
		end
	end
end
