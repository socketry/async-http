# frozen_string_literal: true
#
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

require 'protocol/http/body/stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Output
					def initialize(stream, body, trailer = nil)
						@stream = stream
						@body = body
						@trailer = trailer
						
						@task = nil
						
						@window_updated = Async::Condition.new
					end
					
					attr :trailer
					
					def start(parent: Task.current)
						raise "Task already started!" if @task
						
						if @body.stream?
							@task = parent.async(&self.method(:stream))
						else
							@task = parent.async(&self.method(:passthrough))
						end
					end
					
					def window_updated(size)
						@window_updated.signal
					end
					
					def write(chunk)
						until chunk.empty?
							maximum_size = @stream.available_frame_size
							
							while maximum_size <= 0
								@window_updated.wait
								
								maximum_size = @stream.available_frame_size
							end
							
							break unless chunk = send_data(chunk, maximum_size)
						end
					end
					
					# This method should only be called from within the context of the output task.
					def close(error = nil)
						if @stream
							@stream.finish_output(error)
							@stream = nil
						end
					end
					
					# This method should only be called from within the context of the HTTP/2 stream.
					def stop(error)
						@task&.stop
						@task = nil
					end
					
					private
					
					def stream(task)
						task.annotate("Streaming #{@body} to #{@stream}.")
						
						input = @stream.wait_for_input
						
						@body.call(::Protocol::HTTP::Body::Stream.new(input, self))
					rescue Async::Stop
						# Ignore.
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
						
						self.close
					ensure
						@body&.close($!)
						@body = nil
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
