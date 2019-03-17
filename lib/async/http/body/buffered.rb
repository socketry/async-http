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
			# A body which buffers all it's contents.
			class Buffered < Readable
				# Wraps an array into a buffered body.
				# @return [Readable, nil] the wrapped body or nil if nil was given.
				def self.wrap(body)
					if body.is_a? Async::HTTP::Body::Readable
						return body
					elsif body.is_a? Array
						return self.new(body)
					elsif body.is_a?(String)
						return self.new([body])
					elsif body
						return self.for(body)
					end
				end
				
				def self.for(body)
					chunks = []
					
					body.each do |chunk|
						chunks << chunk
					end
					
					self.new(chunks)
				end
				
				def initialize(chunks, length = nil)
					@chunks = chunks
					@length = length
					
					@index = 0
				end
				
				def finish
					self
				end
				
				def length
					@length ||= @chunks.inject(0) {|sum, chunk| sum + chunk.bytesize}
				end
				
				def empty?
					@index >= @chunks.length
				end
				
				def read
					if chunk = @chunks[@index]
						@index += 1
					end
					
					return chunk&.dup
				end
				
				def rewind
					@index = 0
				end
				
				def inspect
					"\#<#{self.class} #{@chunks.count} chunks, #{self.length} bytes>"
				end
			end
		end
	end
end
