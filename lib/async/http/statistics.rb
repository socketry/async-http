# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "protocol/http/body/wrapper"

require "async/clock"

module Async
	module HTTP
		# Tracks response timing statistics including time to first byte and total duration.
		class Statistics
			# Start tracking statistics from the current time.
			# @returns [Statistics] A new statistics instance.
			def self.start
				self.new(Clock.now)
			end
			
			# Initialize the statistics tracker.
			# @parameter start_time [Float] The start time for measuring durations.
			def initialize(start_time)
				@start_time = start_time
			end
			
			# Wrap a response body with a statistics-collecting wrapper.
			# @parameter response [Protocol::HTTP::Response] The response to wrap.
			# @returns [Protocol::HTTP::Response] The wrapped response.
			def wrap(response, &block)
				if response and response.body
					response.body = Body::Statistics.new(@start_time, response.body, block)
				end
				
				return response
			end
		end
		
		module Body
			# Invokes a callback once the body has finished reading.
			class Statistics < ::Protocol::HTTP::Body::Wrapper
				# Initialize the statistics body wrapper.
				# @parameter start_time [Float] The start time for measuring durations.
				# @parameter body [Protocol::HTTP::Body::Readable] The body to wrap.
				# @parameter callback [Proc] A callback to invoke when the body is closed.
				def initialize(start_time, body, callback)
					super(body)
					
					@sent = 0
					
					@start_time = start_time
					@first_chunk_time = nil
					@end_time = nil
					
					@callback = callback
				end
				
				attr :start_time
				attr :first_chunk_time
				attr :end_time
				
				attr :sent
				
				# @returns [Float | Nil] The total duration from start to close, in seconds.
				def total_duration
					if @end_time
						@end_time - @start_time
					end
				end
				
				# @returns [Float | Nil] The duration from start until the first chunk was read, in seconds.
				def first_chunk_duration
					if @first_chunk_time
						@first_chunk_time - @start_time
					end
				end
				
				# Close the body and record the end time.
				def close(error = nil)
					complete_statistics(error)
					
					super
				end
				
				# Read the next chunk from the body, tracking timing and bytes sent.
				# @returns [String | Nil] The next chunk of data.
				def read
					chunk = super
					
					@first_chunk_time ||= Clock.now
					
					if chunk
						@sent += chunk.bytesize
					end
					
					return chunk
				end
				
				# @returns [String] A human-readable summary of the statistics.
				def to_s
					parts = ["sent #{@sent} bytes"]
					
					if duration = self.total_duration
						parts << "took #{format_duration(duration)} in total"
					end
					
					if duration = self.first_chunk_duration
						parts << "took #{format_duration(duration)} until first chunk"
					end
					
					return parts.join("; ")
				end
				
				# @returns [String] A detailed representation including the wrapped body.
				def inspect
					"#{super} | \#<#{self.class} #{self.to_s}>"
				end
				
				private
				
				def complete_statistics(error = nil)
					@end_time = Clock.now
					
					@callback.call(self, error) if @callback
				end
				
				def format_duration(seconds)
					if seconds < 1.0
						return "#{(seconds * 1000.0).round(2)}ms"
					else
						return "#{seconds.round(1)}s"
					end
				end
			end
		end
	end
end
