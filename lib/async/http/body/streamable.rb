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
			class Streamable < Wrapper
				def self.wrap(message, &block)
					if message and message.body
						if remaining = message.headers['content-length']
							remaining = Integer(remaining)
						end
						
						message.body = self.new(message.body, block, remaining)
					else
						yield
					end
				end
				
				def initialize(body, callback, remaining = nil)
					super(body)
					
					@callback = callback
					@remaining = remaining
				end
				
				def stop(*)
					super
					
					@callback.call
				end
				
				def read
					if chunk = super
						@remaining -= chunk.bytesize if @remaining
					else
						if @remaining and @remaining > 0
							raise EOFError, "Expected #{@remaining} more bytes!"
						end
						
						@callback.call
					end
					
					return chunk
				end
			end
		end
	end
end
