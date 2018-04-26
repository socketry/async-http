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

require_relative 'readable'

module Async
	module HTTP
		module Body
			class Fixed < Readable
				CHUNK_SIZE = 1024*8
				
				def initialize(stream, length)
					@stream = stream
					@length = length
					@remaining = length
				end
				
				def empty?
					@remaining == 0
				end
				
				def read
					if @remaining > 0
						amount = [@remaining, CHUNK_SIZE].min
						
						if chunk = @stream.read(amount)
							@remaining -= chunk.bytesize
							
							return chunk
						end
					end
				end
				
				def join
					buffer = @stream.read(@remaining)
					
					@remaining = 0
					
					return buffer
				end
				
				def inspect
					"\#<#{self.class} length=#{@length} remaining=#{@remaining}>"
				end
			end
			
			class Remainder < Readable
				def initialize(stream)
					@stream = stream
				end
				
				def empty?
					@stream.closed?
				end
				
				def read
					@stream.read unless @stream.closed?
				end
				
				def join
					read
				end
				
				def inspect
					"\#<#{self.class} #{@stream.closed? ? 'closed' : 'open'}>"
				end
			end
		end
	end
end
