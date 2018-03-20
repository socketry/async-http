# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'http11'

require_relative 'request'
require_relative 'response'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP10 < HTTP11
				VERSION = "HTTP/1.0".freeze
				
				def version
					VERSION
				end
				
				def keep_alive?(headers)
					headers[HTTP_CONNECTION] == KEEP_ALIVE
				end
				
				# Server loop.
				def receive_requests
					while request = Request.new(*self.read_request)
						status, headers, body = yield request
						
						write_response(request.version, status, headers, body)
						
						unless keep_alive?(request.headers) && keep_alive?(headers)
							@keep_alive = false
							break
						end
					end
					
					return false
				end
				
				def write_body(body, chunked = true)
					buffer = String.new
					body.each{|chunk| buffer << chunk}
						
					@stream.write("Content-Length: #{buffer.bytesize}\r\n\r\n")
					@stream.write(buffer)
				end
				
				def read_body(headers)
					if content_length = headers[HTTP_CONTENT_LENGTH]
						return @stream.read(Integer(content_length))
					elsif !keep_alive?(headers)
						return @stream.read
					end
				end
			end
		end
	end
end
