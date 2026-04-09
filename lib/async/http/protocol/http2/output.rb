# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require "protocol/http/body/stream"

module Async
	module HTTP
		module Protocol
			module HTTP2
				# Writes body data to an HTTP/2 stream, respecting flow control windows.
				class Output
					# Initialize the output handler.
					# @parameter stream [Stream] The HTTP/2 stream to write to.
					# @parameter body [Protocol::HTTP::Body::Readable] The body to read from.
					# @parameter trailer [Protocol::HTTP::Headers | Nil] Optional trailing headers.
					def initialize(stream, body, trailer = nil)
						@stream = stream
						@body = body
						@trailer = trailer
						
						@task = nil
						
						@guard = ::Mutex.new
						@window_updated = ::ConditionVariable.new
					end
					
					attr :trailer
					
					# Start an asynchronous task to write the body to the stream.
					def start(parent: Task.current)
						raise "Task already started!" if @task
						
						if @body.stream?
							@task = parent.async(&self.method(:stream))
						else
							@task = parent.async(&self.method(:passthrough))
						end
					end
					
					# Signal that the flow control window has been updated.
					# @parameter size [Integer] The new window size.
					# @returns [Boolean] Always returns `true`.
					def window_updated(size)
						@guard.synchronize do
							@window_updated.signal
						end
						
						return true
					end
					
					# Write a chunk of data to the HTTP/2 stream, respecting flow control.
					# @parameter chunk [String] The data to write.
					def write(chunk)
						until chunk.empty?
							maximum_size = @stream.available_frame_size
							
							# We try to avoid synchronization if possible:
							if maximum_size <= 0
								@guard.synchronize do
									maximum_size = @stream.available_frame_size
									
									while maximum_size <= 0
										@window_updated.wait(@guard)
										
										maximum_size = @stream.available_frame_size
									end
								end
							end
							
							break unless chunk = send_data(chunk, maximum_size)
						end
					end
					
					# Finish writing to the stream.
					# @parameter error [Exception | Nil] An optional error that caused the close.
					def close_write(error = nil)
						if stream = @stream
							@stream = nil
							stream.finish_output(error)
						end
					end
					
					# This method should only be called from within the context of the output task.
					def close(error = nil)
						close_write(error)
						stop(error)
					end
					
					# This method should only be called from within the context of the HTTP/2 stream.
					def stop(error)
						if task = @task
							@task = nil
							task.stop(error)
						end
					end
					
					private
					
					def stream(task)
						task.annotate("Streaming #{@body} to #{@stream}.")
						
						input = @stream.wait_for_input
						stream = ::Protocol::HTTP::Body::Stream.new(input, self)
						
						@body.call(stream)
					rescue => error
						self.close(error)
						raise
					end
					
					# Reads chunks from the given body and writes them to the stream as fast as possible.
					def passthrough(task)
						task.annotate("Writing #{@body} to #{@stream}.")
						
						while chunk = @body&.read
							self.write(chunk)
							# TODO this reduces memory usage?
							# chunk.clear unless chunk.frozen?
							# GC.start
						end
					rescue => error
						raise
					ensure
						# Ensure the body we are reading from is fully closed:
						if body = @body
							@body = nil
							body.close(error)
						end
						
						# Ensure the output of this body is closed:
						self.close_write(error)
					end
					
					# Send `maximum_size` bytes of data using the specified `stream`. If the buffer has no more chunks, `END_STREAM` will be sent on the final chunk.
					# @param maximum_size [Integer] send up to this many bytes of data.
					# @param stream [Stream] the stream to use for sending data frames.
					# @return [String, nil] any data that could not be written.
					def send_data(chunk, maximum_size)
						if chunk.bytesize <= maximum_size
							@stream.send_data(chunk, maximum_size: maximum_size)
						else
							@stream.send_data(chunk.byteslice(0, maximum_size), maximum_size: maximum_size)
							
							# The window was not big enough to send all the data, so we save it for next time:
							return chunk.byteslice(maximum_size, chunk.bytesize - maximum_size)
						end
						
						return nil
					end
				end
			end
		end
	end
end
