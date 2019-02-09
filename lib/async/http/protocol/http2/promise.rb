# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
				class Promise < Response
					def initialize(protocol, headers, stream_id)
						super(protocol, stream_id)
						
						@request = build_request(headers)
					end
					
					attr :stream
					attr :request
					
					private def build_request(headers)
						request = HTTP::Request.new
						request.headers = Headers.new
						
						headers.each do |key, value|
							if key == SCHEME
								return @stream.send_failure(400, "Request scheme already specified") if request.scheme
								
								request.scheme = value
							elsif key == AUTHORITY
								return @stream.send_failure(400, "Request authority already specified") if request.authority
								
								request.authority = value
							elsif key == METHOD
								return @stream.send_failure(400, "Request method already specified") if request.method
								
								request.method = value
							elsif key == PATH
								return @stream.send_failure(400, "Request path already specified") if request.path
								
								request.path = value
							else
								request.headers[key] = value
							end
						end
						
						return request
					end
					
					undef send_request
				end
			end
		end
	end
end
