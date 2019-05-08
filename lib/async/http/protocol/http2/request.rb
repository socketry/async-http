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
require_relative 'connection'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Request < Protocol::Request
					def initialize(protocol, stream_id)
						super(nil, nil, nil, nil, VERSION, Headers.new)
						
						@input = nil
						@protocol = protocol
						@stream = Stream.new(self, protocol, stream_id)
					end
					
					attr :stream
					
					def hijack?
						false
					end
					
					def push?
						@protocol.enable_push?
					end
					
					def create_promise_stream(headers, stream_id)
						request = self.class.new(@protocol, stream_id)
						request.receive_headers(self, headers, false)
						
						return request.stream
					end
					
					def close!(state)
					end
					
					# @return [Stream] the promised stream, on which to send data.
					def push(path, headers = nil)
						push_headers = [
							[SCHEME, @scheme],
							[METHOD, GET],
							[PATH, path],
							[AUTHORITY, @authority]
						]
						
						if headers
							push_headers = Headers::Merged.new(
								push_headers,
								headers
							)
						end
						
						@stream.send_push_promise(push_headers)
					end
					
					def receive_headers(stream, headers, end_stream)
						headers.each do |key, value|
							if key == SCHEME
								return @stream.send_failure(400, "Request scheme already specified") if @scheme
								
								@scheme = value
							elsif key == AUTHORITY
								return @stream.send_failure(400, "Request authority already specified") if @authority
								
								@authority = value
							elsif key == METHOD
								return @stream.send_failure(400, "Request method already specified") if @method
								
								@method = value
							elsif key == PATH
								return @stream.send_failure(400, "Request path already specified") if @path
								
								@path = value
							else
								@headers[key] = value
							end
						end
						
						# We only construct the input/body if data is coming.
						unless end_stream
							@body = @input = Body::Writable.new
						end
						
						# We are ready for processing:
						@protocol.requests.enqueue self
					end
					
					def receive_data(stream, data, end_stream)
						unless data.empty?
							@input.write(data)
						end
						
						if end_stream
							@input.close
						end
					end
					
					def receive_reset_stream(stream, error_code)
					end
					
					def stop_connection(error)
					end
					
					NO_RESPONSE = [
						[STATUS, '500'],
						[REASON, "No response generated"]
					]
					
					def send_response(response)
						if response.nil?
							@stream.send_headers(nil, NO_RESPONSE, ::Protocol::HTTP2::END_STREAM)
						elsif response.body?
							pseudo_headers = [
								[STATUS, response.status],
							]
							
							if length = response.body.length
								pseudo_headers << [CONTENT_LENGTH, length]
							end
							
							headers = Headers::Merged.new(
								pseudo_headers,
								response.headers
							)
							
							@stream.send_headers(nil, headers)
							@stream.send_body(response.body)
						else
							headers = Headers::Merged.new([
								[STATUS, response.status],
							], response.headers)
							
							@stream.send_headers(nil, headers, ::Protocol::HTTP2::END_STREAM)
						end
					end
				end
			end
		end
	end
end
