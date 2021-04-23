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

require_relative '../response'
require_relative 'stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				# Typically used on the client side for writing a request and reading the incoming response.
				class Response < Protocol::Response
					class Stream < HTTP2::Stream
						def initialize(*)
							super
							
							@response = Response.new(self)
							
							@notification = Async::Notification.new
							@exception = nil
						end
						
						attr :response
						
						def wait_for_input
							# The input isn't ready until the response headers have been received:
							@response.wait
							
							# There is a possible race condition if you try to access @input - it might already be closed and nil.
							return @response.body
						end
						
						def accept_push_promise_stream(promised_stream_id, headers)
							raise ProtocolError, "Cannot accept push promise stream!"
						end
						
						# This should be invoked from the background reader, and notifies the task waiting for the headers that we are done.
						def receive_initial_headers(headers, end_stream)
							headers.each do |key, value|
								if key == STATUS
									@response.status = Integer(value)
								elsif key == PROTOCOL
									@response.protocol = value
								elsif key == CONTENT_LENGTH
									@length = Integer(value)
								else
									add_header(key, value)
								end
							end
							
							@response.headers = @headers
							
							if @response.valid?
								if !end_stream
									# We only construct the input/body if data is coming.
									@response.body = prepare_input(@length)
								elsif @response.head?
									@response.body = ::Protocol::HTTP::Body::Head.new(@length)
								end
							else
								send_reset_stream(::Protocol::HTTP2::Error::PROTOCOL_ERROR)
							end
							
							self.notify!
							
							return headers
						end
						
						# Notify anyone waiting on the response headers to be received (or failure).
						def notify!
							if notification = @notification
								@notification = nil
								notification.signal
							end
						end
						
						# Wait for the headers to be received or for stream reset.
						def wait
							# If you call wait after the headers were already received, it should return immediately:
							@notification&.wait
							
							if @exception
								raise @exception
							end
						end
						
						def closed(error)
							super
							
							if @response
								@response = nil
							end
							
							@exception = error
							
							notify!
						end
					end
					
					def initialize(stream)
						super(stream.connection.version, nil, nil)
						
						@stream = stream
						@request = nil
					end
					
					attr :stream
					attr :request
					
					def connection
						@stream.connection
					end
					
					def wait
						@stream.wait
					end
					
					def head?
						@request&.head?
					end
					
					def valid?
						!!@status
					end
					
					def build_request(headers)
						request = ::Protocol::HTTP::Request.new
						request.headers = ::Protocol::HTTP::Headers.new
						
						headers.each do |key, value|
							if key == SCHEME
								raise ::Protocol::HTTP2::HeaderError, "Request scheme already specified!" if request.scheme
								
								request.scheme = value
							elsif key == AUTHORITY
								raise ::Protocol::HTTP2::HeaderError, "Request authority already specified!" if request.authority
								
								request.authority = value
							elsif key == METHOD
								raise ::Protocol::HTTP2::HeaderError, "Request method already specified!" if request.method
								
								request.method = value
							elsif key == PATH
								raise ::Protocol::HTTP2::HeaderError, "Request path is empty!" if value.empty?
								raise ::Protocol::HTTP2::HeaderError, "Request path already specified!" if request.path
								
								request.path = value
							elsif key.start_with? ':'
								raise ::Protocol::HTTP2::HeaderError, "Invalid pseudo-header #{key}!"
							else
								request.headers[key] = value
							end
						end
						
						@request = request
					end
					
					# Send a request and read it into this response.
					def send_request(request)
						@request = request
						
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
						
						if protocol = request.protocol
							pseudo_headers << [PROTOCOL, protocol]
						end
						
						headers = ::Protocol::HTTP::Headers::Merged.new(
							pseudo_headers,
							request.headers
						)
						
						if request.body.nil?
							@stream.send_headers(nil, headers, ::Protocol::HTTP2::END_STREAM)
						else
							if length = request.body.length
								# This puts it at the end of the pseudo-headers:
								pseudo_headers << [CONTENT_LENGTH, length]
							end
							
							# This function informs the headers object that any subsequent headers are going to be trailer. Therefore, it must be called *before* sending the headers, to avoid any race conditions.
							trailer = request.headers.trailer!
							
							begin
								@stream.send_headers(nil, headers)
							rescue
								raise RequestFailed
							end
							
							@stream.send_body(request.body, trailer)
						end
					end
				end
			end
		end
	end
end
