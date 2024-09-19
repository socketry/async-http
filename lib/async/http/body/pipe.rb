# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

require_relative "writable"

module Async
	module HTTP
		module Body
			class Pipe
				# If the input stream is closed first, it's likely the output stream will also be closed.
				def initialize(input, output = Writable.new, task: Task.current)
					@input = input
					@output = output
					
					head, tail = ::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@head = ::IO::Stream(head)
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
				rescue => error
					raise
				ensure
					@input.close(error)
					
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
				rescue => error
					raise
				ensure
					@output.close_write(error)
					
					close_head if @reader&.finished?
				end
				
				def close_head
					@head.close
					
					# Both tasks are done, don't keep references:
					@reader = nil
					@writer = nil
				end
			end
		end
	end
end
