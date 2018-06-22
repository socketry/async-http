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

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP10 < HTTP11
				KEEP_ALIVE = 'keep-alive'.freeze
				
				VERSION = "HTTP/1.0".freeze
				
				def version
					VERSION
				end
				
				def persistent?(headers)
					if connection = headers[CONNECTION]
						return connection.include?(KEEP_ALIVE)
					else
						return false
					end
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while @persistent
						request = Request.new(*self.read_request)
						
						unless persistent?(request.headers)
							@persistent = false
						end
						
						response = yield request
						
						response.version ||= request.version
						
						write_response(response.version, response.status, response.headers, response.body)
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				def write_persistent_header
					@stream.write("connection: keep-alive\r\n") if @persistent
				end
				
				def write_body(body, chunked = false)
					# We don't support chunked encoding.
					super(body, chunked)
				end
				
				def read_body(headers)
					if body = super
						return body
					end
					
					# Technically, with HTTP/1.0, if no content-length is specified, we just need to read everything until the connection is closed.
					unless @persistent
						return Body::Remainder.new(@stream)
					end
				end
			end
		end
	end
end
