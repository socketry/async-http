# frozen_string_literal: true
#
# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'protocol/http/body/wrapper'

require 'async/clock'

module Async
	module HTTP
		class Statistics
			def self.start
				self.new(Clock.now)
			end
			
			def initialize(start_time)
				@start_time = start_time
			end
			
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
				
				def total_duration
					if @end_time
						@end_time - @start_time
					end
				end
				
				def first_chunk_duration
					if @first_chunk_time
						@first_chunk_time - @start_time
					end
				end
				
				def close(error = nil)
					complete_statistics(error)
					
					super
				end
				
				def read
					chunk = super
					
					@first_chunk_time ||= Clock.now
					
					if chunk
						@sent += chunk.bytesize
					end
					
					return chunk
				end
				
				def to_s
					parts = ["sent #{@sent} bytes"]
					
					if duration = self.total_duration
						parts << "took #{format_duration(duration)} in total"
					end
					
					if duration = self.first_chunk_duration
						parts << "took #{format_duration(duration)} until first chunk"
					end
					
					return parts.join('; ')
				end
				
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
