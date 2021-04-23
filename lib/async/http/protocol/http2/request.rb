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

require_relative '../request'
require_relative 'stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				# Typically used on the server side to represent an incoming request, and write the response.
				class Request < Protocol::Request
					class Stream < HTTP2::Stream
						def initialize(*)
							super
							
							@enqueued = false
							@request = Request.new(self)
						end
						
						attr :request
						
						def receive_initial_headers(headers, end_stream)
							headers.each do |key, value|
								if key == SCHEME
									raise ::Protocol::HTTP2::HeaderError, "Request scheme already specified!" if @request.scheme
									
									@request.scheme = value
								elsif key == AUTHORITY
									raise ::Protocol::HTTP2::HeaderError, "Request authority already specified!" if @request.authority
									
									@request.authority = value
								elsif key == METHOD
									raise ::Protocol::HTTP2::HeaderError, "Request method already specified!" if @request.method
									
									@request.method = value
								elsif key == PATH
									raise ::Protocol::HTTP2::HeaderError, "Request path is empty!" if value.empty?
									raise ::Protocol::HTTP2::HeaderError, "Request path already specified!" if @request.path
									
									@request.path = value
								elsif key == PROTOCOL
									raise ::Protocol::HTTP2::HeaderError, "Request protocol already specified!" if @request.protocol
									
									@request.protocol = value
								elsif key == CONTENT_LENGTH
									raise ::Protocol::HTTP2::HeaderError, "Request content length already specified!" if @length
									
									@length = Integer(value)
								elsif key == CONNECTION
									raise ::Protocol::HTTP2::HeaderError, "Connection header is not allowed!"
								elsif key.start_with? ':'
									raise ::Protocol::HTTP2::HeaderError, "Invalid pseudo-header #{key}!"
								elsif key =~ /[A-Z]/
									raise ::Protocol::HTTP2::HeaderError, "Invalid characters in header #{key}!"
								else
									add_header(key, value)
								end
							end
							
							@request.headers = @headers
							
							unless @request.valid?
								raise ::Protocol::HTTP2::HeaderError, "Request is missing required headers!"
							else
								# We only construct the input/body if data is coming.
								unless end_stream
									@request.body = prepare_input(@length)
								end
								
								# We are ready for processing:
								@connection.requests.enqueue(@request)
							end
							
							return headers
						end
						
						def closed(error)
							@request = nil
							
							super
						end
					end
					
					def initialize(stream)
						super(nil, nil, nil, nil, VERSION, nil)
						
						@stream = stream
					end
					
					attr :stream
					
					def connection
						@stream.connection
					end
					
					def valid?
						@scheme and @method and @path
					end
					
					def hijack?
						false
					end
					
					NO_RESPONSE = [
						[STATUS, '500'],
					]
					
					def send_response(response)
						if response.nil?
							return @stream.send_headers(nil, NO_RESPONSE, ::Protocol::HTTP2::END_STREAM)
						end
						
						protocol_headers = [
							[STATUS, response.status],
						]
						
						if protocol = response.protocol
							protocol_headers << [PROTOCOL, protocol]
						end
						
						if length = response.body&.length
							protocol_headers << [CONTENT_LENGTH, length]
						end
						
						headers = ::Protocol::HTTP::Headers::Merged.new(protocol_headers, response.headers)
						
						if body = response.body and !self.head?
							# This function informs the headers object that any subsequent headers are going to be trailer. Therefore, it must be called *before* sending the headers, to avoid any race conditions.
							trailer = response.headers.trailer!
							
							@stream.send_headers(nil, headers)
							
							@stream.send_body(body, trailer)
						else
							# Ensure the response body is closed if we are ending the stream:
							response.close
							
							@stream.send_headers(nil, headers, ::Protocol::HTTP2::END_STREAM)
						end
					end
				end
			end
		end
	end
end
