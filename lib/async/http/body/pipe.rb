# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

require_relative "writable"

module Async
	module HTTP
		module Body
			# A bidirectional pipe that connects an input body to an output body using a Unix socket pair.
			class Pipe
				# Ensure the returned socket retains ownership of the pipe and closes it explicitly.
				module OwnedSocket
					# Close the owning pipe, or the underlying socket if ownership has already been released.
					def close
						if pipe = @async_http_pipe
							@async_http_pipe = nil
							pipe.close
						else
							super
						end
					end
				end
				
				private_constant :OwnedSocket
				
				# If the input stream is closed first, it's likely the output stream will also be closed.
				def initialize(input, output = Writable.new, task: Task.current)
					@input = input
					@output = output
					
					head, tail = ::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@head = ::IO::Stream(head)
					@tail = tail
					
					# Capture the original close method so the pipe can close the socket without recursively invoking the ownership callback.
					@close_tail = tail.method(:close)
					
					tail.extend(OwnedSocket)
					tail.instance_variable_set(:@async_http_pipe, self)
					
					@reader = nil
					@writer = nil
					
					task.async(transient: true, &self.method(:reader))
					task.async(transient: true, &self.method(:writer))
				end
				
				# The returned socket owns the pipe; closing it explicitly closes the forwarding tasks and both bodies.
				# @returns [IO] The underlying IO object for the tail of the pipe.
				def to_io
					@tail
				end
				
				# Close the pipe and stop the reader and writer tasks.
				def close
					if close_tail = @close_tail
						@close_tail = nil
						@tail.instance_variable_set(:@async_http_pipe, nil)
						
						@reader&.stop
						@writer&.stop
						
						close_tail.call
					end
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
