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
						@input = Body::Writable.new
						
						super(nil, nil, nil, VERSION, Headers.new, @input)
						
						@protocol = protocol
						@stream = Stream.new(self, protocol, stream_id)
					end
					
					attr :stream
					
					def hijack?
						false
					end
					
					def receive_headers(stream, headers, end_stream)
						headers.each do |key, value|
							if key == METHOD
								return @stream.send_failure(400, "Request method already specified") if @method
								
								@method = value
							elsif key == PATH
								return @stream.send_failure(400, "Request path already specified") if @path
								
								@path = value
							elsif key == AUTHORITY
								return @stream.send_failure(400, "Request authority already specified") if @authority
								
								@authority = value
							else
								@headers[key] = value
							end
						end
						
						# We are ready for processing:
						@protocol.requests.enqueue self
					end
					
					def receive_data(stream, data, end_stream)
						unless data.empty?
							@input.write(data)
						end
						
						if end_stream
							@input.finish
						end
					end
					
					def receive_reset_stream(stream, error_code)
					end
					
					NO_RESPONSE = [
						[STATUS, '500'],
						[REASON, "No response generated"]
					]
					
					def send_response(response)
						if response.nil?
							@stream.send_headers(nil, NO_RESPONSE, ::HTTP::Protocol::HTTP2::END_STREAM)
						elsif response.body?
							headers = Headers::Merged.new([
								[STATUS, response.status],
							])
							
							if length = response.body.length
								headers << [[CONTENT_LENGTH, length]]
							end
							
							headers << response.headers
							
							@stream.send_headers(nil, headers)
							@stream.send_body(response.body)
						else
							headers = Headers::Merged.new([
								[STATUS, response.status],
							], response.headers)
							
							@stream.send_headers(nil, headers, ::HTTP::Protocol::HTTP2::END_STREAM)
						end
					end
				end
			end
		end
	end
end
