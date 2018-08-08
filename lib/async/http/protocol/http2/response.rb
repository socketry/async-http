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

require_relative '../response'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Response < Protocol::Response
					def initialize(protocol, stream_id)
						@input = nil
						
						super(protocol.version, nil, nil, Headers.new, nil)
						
						@protocol = protocol
						@stream = Stream.new(self, protocol, stream_id)
						
						@notification = Async::Notification.new
						@exception = nil
					end
					
					def wait
						@notification.wait
						
						if @exception
							raise @exception
						end
					end
					
					def receive_headers(stream, headers, end_stream)
						headers.each do |key, value|
							if key == STATUS
								@status = value.to_i
							elsif key == REASON
								@reason = value
							else
								@headers[key] = value
							end
						end
						
						unless end_stream
							@body = @input = Body::Writable.new
						end
						
						# We are ready for processing:
						@notification.signal
					end
					
					def receive_data(stream, data, end_stream)
						unless data.empty?
							@input.write(data)
						end
						
						if end_stream
							@input.finish
						end
					rescue EOFError
						@stream.send_reset_stream(0)
					end
					
					def receive_reset_stream(stream, error_code)
						if error_code > 0
							@exception = EOFError.new(error_code)
						end
						
						@notification.signal
					end
					
					def send_request(request)
						headers = Headers::Merged.new({
							SCHEME => HTTPS,
							METHOD => request.method,
							PATH => request.path,
							AUTHORITY => request.authority,
						}, request.headers)
						
						if request.body.nil?
							@stream.send_headers(nil, headers, ::HTTP::Protocol::HTTP2::END_STREAM)
						else
							begin
								@stream.send_headers(nil, headers)
							rescue
								raise RequestFailed
							end
							
							@stream.send_body(request.body)
						end
					end
				end
			end
		end
	end
end
