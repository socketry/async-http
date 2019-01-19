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
						@length = nil
						
						super(protocol.version, nil, nil, Headers.new, nil)
						
						@protocol = protocol
						@stream = Stream.new(self, protocol, stream_id)
						
						@notification = Async::Notification.new
						@exception = nil
					end
					
					# Notify anyone waiting on the response headers to be received (or failure).
					protected def notify!
						if @notification
							@notification.signal
							@notification = nil
						end
					end
					
					# Wait for the headers to be received or for stream reset.
					def wait
						# If you call wait after the headers were already received, it should return immediately.
						if @notification
							@notification.wait
						end
						
						if @exception
							raise @exception
						end
					end
					
					# This should be invoked from the background reader, and notifies the task waiting for the headers that we are done.
					def receive_headers(stream, headers, end_stream)
						headers.each do |key, value|
							if key == STATUS
								@status = Integer(value)
							elsif key == REASON
								@reason = value
							elsif key == CONTENT_LENGTH
								@length = Integer(value)
							else
								@headers[key] = value
							end
						end
						
						unless end_stream
							@body = @input = Body::Writable.new(@length)
						end
						
						notify!
					end
					
					def receive_data(stream, data, end_stream)
						unless data.empty?
							@input.write(data)
						end
						
						if end_stream
							@input.close
						end
					rescue
						@stream.send_reset_stream(0)
					end
					
					def receive_reset_stream(stream, error_code)
						if error_code > 0
							@exception = EOFError.new("Stream reset: error_code=#{error_code}")
						end
						
						notify!
					end
					
					def stop_connection(error)
						@exception = error
						
						notify!
					end
					
					# Send a request and read it into this response.
					def send_request(request)
						# https://http2.github.io/http2-spec/#rfc.section.8.1.2.3
						# All HTTP/2 requests MUST include exactly one valid value for the :method, :scheme, and :path pseudo-header fields, unless it is a CONNECT request (Section 8.3). An HTTP request that omits mandatory pseudo-header fields is malformed (Section 8.1.2.6).
						pseudo_headers = [
							[SCHEME, request.scheme],
							[METHOD, request.method],
							[PATH, request.path],
						]
						
						# To ensure that the HTTP/1.1 request line can be reproduced accurately, this pseudo-header field MUST be omitted when translating from an HTTP/1.1 request that has a request target in origin or asterisk form (see [RFC7230], Section 5.3). Clients that generate HTTP/2 requests directly SHOULD use the :authority pseudo-header field instead of the Host header field.
						if authority = request.authority
							pseudo_headers << [AUTHORITY, authority]
						end
						
						headers = Headers::Merged.new(
							pseudo_headers,
							request.headers
						)
						
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
