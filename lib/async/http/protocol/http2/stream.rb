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
					def initialize(delegate, *args)
						super(*args)
						
						@delegate = delegate
						
						# This is the body that is being sent.
						@body = nil
						
						# The remainder of the current chunk being sent.
						@remainder = nil
						
						# The task that is handling sending the body.
						@task = nil
					end
					
					attr_accessor :delegate
					attr :body
					
					def create_push_promise_stream(headers)
						@delegate.create_push_promise_stream(headers)
					end
					
					def accept_push_promise_stream(headers, stream_id)
						@delegate.accept_push_promise_stream(headers, stream_id)
					end
					
					# Set the body and begin sending it.
					def send_body(body, task: Task.current)
						@body = body
					end
					
					def data_available?
						@body or @remainder
					end
					
					def next_chunk
						# Figure out what we are going to send:
						if @remainder
							chunk = @remainder
							@remainder = nil
						elsif chunk = @body&.read # This is a non-blocking operation.
							# There was a new chunk of data to send.
						elsif @body
							# We had a body, and it didn't give us any more chunks, so it's finished:
							@body.close
							@body = nil
							
							# It's possible that the stream has been closed at this point:
							unless self.closed?
								send_data(nil, ::Protocol::HTTP2::END_STREAM)
							end
							
							# There is no more data to send:
							return false
						else
							# There was no data and no body:
							return false
						end
						
						return chunk
					end
					
					def write_data(maximum_size)
						# This operation is non-blocking:
						return unless chunk = next_chunk
						
						# We want to send a chunk but the stream has been closed, so we are done:
						return false if closed?
						
						# The flow control window doesn't have any available capacity, we are finished:
						if maximum_size <= 0
							@remainder = chunk
							return false
						end
						
						# Send as much of the chunk as possible:
						if chunk.bytesize <= maximum_size
							send_data(chunk, maximum_size: maximum_size)
							
							# We can send another chunk of data:
							return true
						else
							send_data(chunk.byteslice(0, maximum_size), maximum_size: maximum_size)
							
							# The window was not big enough to send all the data, so we save it for next time:
							@remainder = chunk.byteslice(maximum_size, chunk.bytesize - maximum_size)
							
							# We need to wait for another window update before we can continue sending data:
							return false
						end
					end
					
					def receive_headers(frame)
						headers = super
						
						@delegate.receive_headers(self, headers, frame.end_stream?)
						
						return headers
					end
					
					def receive_data(frame)
						data = super
						
						if data
							@delegate.receive_data(self, data, frame.end_stream?)
						end
						
						return data
					end
					
					def receive_reset_stream(frame)
						error_code = super
						
						if @body
							@body.close(EOFError.new(error_code))
							@body = nil
						end
						
						@delegate.receive_reset_stream(self, error_code)
						
						return error_code
					end
					
					def close!(error_code = nil)
						@delegate.close!
						
						super
					end
					
					def close(error = nil)
						super
						
						if @body
							@body.close(error)
							@body = nil
						end
						
						@delegate.stream_closed(error)
					end
				end
			end
		end
	end
end
