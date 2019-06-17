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

require 'protocol/http2/stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Stream < ::Protocol::HTTP2::Stream
					class Buffer
						def initialize(stream, body, task: Task.current)
							@stream = stream
							
							@body = body
							@remainder = nil
							
							@window_updated = Async::Condition.new
							
							@task = task.async do
								while chunk = self.read
									maximum_size = @stream.available_frame_size
									
									while maximum_size <= 0
										@window_updated.wait
										
										maximum_size = @stream.available_frame_size
									end
									
									self.send_data(chunk, maximum_size)
								end
								
								self.end_stream
							rescue Errno::EPIPE
								# Ignore.
							ensure
								@body&.close($!)
								@body = nil
							end
						end
						
						def read
							if @remainder
								remainder = @remainder
								@remainder = nil
								
								return remainder
							else
								@body.read
							end
						end
						
						def push(chunk)
							@remainder = chunk
						end
						
						# Send `maximum_size` bytes of data using the specified `stream`. If the buffer has no more chunks, `END_STREAM` will be sent on the final chunk.
						# @param maximum_size [Integer] send up to this many bytes of data.
						# @param stream [Stream] the stream to use for sending data frames.
						def send_data(chunk, maximum_size)
							if chunk.bytesize <= maximum_size
								@stream.send_data(chunk, maximum_size: maximum_size)
							else
								@stream.send_data(chunk.byteslice(0, maximum_size), maximum_size: maximum_size)
								
								# The window was not big enough to send all the data, so we save it for next time:
								self.push(
									chunk.byteslice(maximum_size, chunk.bytesize - maximum_size)
								)
							end
						end
						
						def end_stream
							@stream.send_data(nil, ::Protocol::HTTP2::END_STREAM)
						end
						
						def window_updated(size)
							@window_updated.signal
						end
						
						def close(error)
							if @body
								@body.close(error)
								@body = nil
							end
						end
					end
					
					def initialize(*)
						super
						
						# Input buffer (receive_data):
						@length = nil
						@input = nil
						
						# Output buffer (window_updated):
						@output = nil
					end
					
					def process_data(frame)
						data = frame.unpack
						
						if @input
							unless data.empty?
								@input.write(data)
							end
							
							if frame.end_stream?
								@input.close
								@input = nil
							end
						end
						
						return data
					rescue ::Protocol::HTTP2::ProtocolError
						raise
					rescue # Anything else...
						send_reset_stream(::Protocol::HTTP2::Error::INTERNAL_ERROR)
					end
					
					# Set the body and begin sending it.
					def send_body(body)
						@output = Buffer.new(self, body)
					end
					
					def window_updated(size)
						super
						
						@output&.window_updated(size)
					end
					
					def close(error = nil)
						super
						
						if @input
							@input.close(error)
							@input = nil
						end
						
						if @output
							@output.close(error)
							@output = nil
						end
					end
				end
			end
		end
	end
end
