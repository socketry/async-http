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
					class Buffer < ::Protocol::HTTP2::Stream::Buffer
						def initialize(stream, body, task: Task.current)
							super(stream)
							
							@body = body
							@window_updates = Async::Queue.new
							@window_updates.enqueue(@stream.available_frame_size)
							
							@task = task.async do
								while chunk = @body&.read
									@chunks.unshift(chunk)
									while !@chunks.empty?
										maximum_size = @stream.available_frame_size
										
										if maximum_size <= 0
											maximum_size = @window_updates.dequeue
										end
										
										self.send_data(self.pop, maximum_size)
									end
								end
								
								self.end_stream
								
								if @body
									@body.close
									@body = nil
								end
							end
						end
						
						def window_updated(size)
							@window_updates.enqueue(size)
						end
						
						# Are we now closed? i.e. further calls to `pop` will give nil.
						def closed?
							@body.nil?
						end
						
						def close(error)
							super
							
							if @body
								@body.close(error)
								@body = nil
							end
						end
						
						def window_updated(size)
						end
					end
					
					def initialize(delegate, *args)
						super(*args)
						
						@delegate = delegate
					end
					
					attr_accessor :delegate
					
					def create_push_promise_stream(headers)
						@delegate.create_push_promise_stream(headers)
					end
					
					def accept_push_promise_stream(headers, stream_id)
						@delegate.accept_push_promise_stream(headers, stream_id)
					end
					
					# Set the body and begin sending it.
					def send_body(body)
						@buffer = Buffer.new(self, body)
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
						
						@delegate.receive_reset_stream(self, error_code)
						
						return error_code
					end
					
					def close!(error_code = nil)
						@delegate.close!
						
						super
					end
					
					def close(error = nil)
						super
						
						@delegate.stream_closed(error)
					end
				end
			end
		end
	end
end
