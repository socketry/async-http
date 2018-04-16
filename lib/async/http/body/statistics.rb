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

require_relative 'wrapper'

module Async
	module HTTP
		module Body
			# Invokes a callback once the body has finished reading.
			class Statistics < Wrapper
				def self.wrap(message, &block)
					message.body = self.new(message.body, block)
				end
				
				def initialize(body, callback)
					super(body)
					
					@bytesize = 0
					
					@start_time = Time.now
					@first_chunk_time = nil
					@end_time = nil
					
					@callback = callback
				end
				
				attr :start_time
				attr :first_chunk_time
				attr :end_time
				
				attr :bytesize
				
				def duration
					@end_time - @start_time
				end
				
				def stop(error)
					complete_statistics
					
					super
				end
				
				def read
					chunk = super
					
					@first_chunk_time ||= Time.now
					
					if chunk
						@bytesize += chunk.bytesize
					else
						complete_statistics
					end
					
					return chunk
				end
				
				private
				
				def complete_statistics
					@end_time = Time.now
					@callback.call(self) if @callback
				end
			end
		end
	end
end
