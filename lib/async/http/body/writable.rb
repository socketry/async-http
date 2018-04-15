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
				def initialize
					@queue = Async::Queue.new
					
					@finished = false
					@stopped = false
				end
				
				def empty?
					@finished
				end
				
				# Enumerate all chunks until finished.
				def each
					return to_enum unless block_given?
					
					return if @finished
					
					while chunk = @queue.dequeue
						yield chunk
					end
				rescue
					# Stop the stream because the remote end is no longer reading from it. Any attempt to write to the stream will fail.
					@stopped = $!
					
					raise
				ensure
					@finished = true
				end
				
				# Read the next available chunk.
				def read
					return if @finished
					
					unless chunk = @queue.dequeue
						@finished = true
					end
					
					return chunk
				end
				
				# Write a single chunk to the body. Signal completion by calling `#finish`.
				def write(chunk)
					if @stopped
						raise @stopped
					end
					
					# TODO should this yield if the queue is full?
					
					@queue.enqueue(chunk)
				end
				
				# Signal that output has finished.
				def finish
					@queue.enqueue(nil)
				end
			end
		end
	end
end
