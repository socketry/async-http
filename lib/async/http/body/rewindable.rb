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
			# A body which buffers all it's contents.
			class Rewindable < Wrapper
				def initialize(body)
					super(body)
					
					@chunks = []
					@index = 0
				end
				
				def read
					if @index < @chunks.count
						chunk = @chunks[@index]
						@index += 1
					else
						if chunk = super
							@chunks << chunk
							@index += 1
						end
					end
					
					# We dup them on the way out, so that if someone modifies the string, it won't modify the rewindability.
					return chunk.dup
				end
				
				def rewind
					@index = 0
				end
				
				def inspect
					"\#<#{self.class} #{@index}/#{@chunks.count} chunks read>"
				end
			end
		end
	end
end
