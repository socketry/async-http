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

require 'async/queue'

module Async
	module HTTP
		module Body
			# A dynamic body which you can write to and read from.
			class Writable < Readable
				class Closed < StandardError
				end
				
				DEFAULT_SIZE = 8
				
				def initialize(length = nil, size = DEFAULT_SIZE)
					@queue = Async::Queue.new
					
					@size = size
					@full = Async::Condition.new
					
					@length = length
					
					@count = 0
					
					@finished = false
					
					@closed = false
					@error = nil
				end
				
				def length
					@length
				end
				
				# Stop generating output; cause the next call to write to fail with the given error.
				def close(error = nil)
					unless @closed
						@queue.enqueue(nil)
						
						@closed = true
						@error = error
					end
					
					super
				end
				
				# Has the producer called #finish and has the reader consumed the nil token?
				def empty?
					@finished
				end
				
				# Read the next available chunk.
				def read
					return if @finished
					
					unless chunk = @queue.dequeue
						@finished = true
					end
					
					@full.signal unless @full.empty?
					
					return chunk
				end
				
				# Write a single chunk to the body. Signal completion by calling `#finish`.
				def write(chunk)
					# If the reader breaks, the writer will break.
					# The inverse of this is less obvious (*)
					if @closed
						raise(@error || Closed)
					end
					
					while @queue.items.count > @size
						@full.wait
					end
					
					@count += 1
					@queue.enqueue(chunk)
				end
				
				alias << write
				
				def inspect
					"\#<#{self.class} #{@count} chunks written#{@finished ? ', finished' : ', waiting'}>"
				end
			end
		end
	end
end
