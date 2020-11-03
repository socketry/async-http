# frozen_string_literal: true
#
# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/io/socket'
require 'async/io/stream'

require_relative 'writable'

module Async
	module HTTP
		module Body
			class Pipe
				# If the input stream is closed first, it's likely the output stream will also be closed.
				def initialize(input, output = Writable.new, task: Task.current)
					@input = input
					@output = output
					
					head, tail = IO::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@head = IO::Stream.new(head)
					@tail = tail
					
					@reader = nil
					@writer = nil
					
					task.async(transient: true, &self.method(:reader))
					task.async(transient: true, &self.method(:writer))
				end
				
				def to_io
					@tail
				end
				
				def close
					@reader&.stop
					@writer&.stop
					
					@tail.close
				end
				
				private
				
				# Read from the @input stream and write to the head of the pipe.
				def reader(task)
					@reader = task
					
					task.annotate "#{self.class} reader."
					
					while chunk = @input.read
						@head.write(chunk)
						@head.flush
					end
					
					@head.close_write
				ensure
					@input.close($!)
					
					close_head if @writer&.finished?
				end
				
				# Read from the head of the pipe and write to the @output stream.
				# If the @tail is closed, this will cause chunk to be nil, which in turn will call `@output.close` and `@head.close`
				def writer(task)
					@writer = task
					
					task.annotate "#{self.class} writer."
					
					while chunk = @head.read_partial
						@output.write(chunk)
					end
				ensure
					@output.close($!)
					
					close_head if @reader&.finished?
				end

				def close_head
					@head.close
					# Both tasks are done, don't keep references.
					@reader = nil
					@writer = nil
				end
			end
		end
	end
end
