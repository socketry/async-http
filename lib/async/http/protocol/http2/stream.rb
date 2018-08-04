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

require 'http/protocol/http2/stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Stream < ::HTTP::Protocol::HTTP2::Stream
					def initialize(delegate, *args)
						super(*args)
						
						@delegate = delegate
						
						@body = body
						@remainder = nil
					end
					
					attr_accessor :delegate
					attr :body
					
					def send_body(body)
						@body = body
						
						window_updated
					end
					
					def send_chunk
						maximum_size = self.available_frame_size
						
						if maximum_size == 0
							return false
						end
						
						if @remainder
							chunk = @remainder
							@remainder = nil
						elsif chunk = @body.read
							# There was a new chunk of data to send
						else
							@body = nil
							
							# @body.read above might take a while and a stream reset might be received in the mean time.
							unless closed?
								send_data(nil, ::HTTP::Protocol::HTTP2::END_STREAM)
							end
							
							return false
						end
						
						return false if closed?
						
						if chunk.bytesize <= maximum_size
							send_data(chunk, maximum_size: maximum_size)
						else
							send_data(chunk.byteslice(0, maximum_size), maximum_size: maximum_size)
							
							@remainder = chunk.byteslice(maximum_size, chunk.bytesize - maximum_size)
						end
						
						return true
					end
					
					def window_updated
						return unless @body
						
						while send_chunk
							# There could be more data to send...
						end
					end
					
					def receive_headers(frame)
						headers = super
						
						delegate.receive_headers(self, headers, frame.end_stream?)
						
						return headers
					end
					
					def receive_data(frame)
						data = super
						
						if data
							delegate.receive_data(self, data, frame.end_stream?)
						end
						
						return data
					end
					
					def receive_reset_stream(frame)
						error_code = super
						
						if @body
							@body.stop(EOFError.new(error_code))
							@body = nil
						end
						
						delegate.receive_reset_stream(self, error_code)
						
						return error_code
					end
				end
			end
		end
	end
end
