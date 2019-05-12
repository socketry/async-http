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

require_relative 'connection'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Server < Connection
					def fail_request(status)
						@persistent = false
						write_response(@version, status, {}, nil)
					end
					
					def next_request
						# The default is true.
						return unless @persistent
						
						# Read an incoming request:
						return unless request = Request.read(self)
						
						unless persistent?(request.version, request.headers)
							@persistent = false
						end
						
						return request
					rescue Async::TimeoutError
						fail_request(408)
						raise
					rescue
						fail_request(400)
						raise
					end
					
					# Server loop.
					def each(task: Task.current)
						while request = next_request
							response = yield(request, self)
							
							return if @stream.closed?
							
							if response
								# Try to avoid holding on to request, to minimse GC overhead:
								head = request.head?
								
								unless request.body?
									# If there is no body, #finish is a no-op.
									request = nil
								end
								
								write_response(@version, response.status, response.headers, response.body, head)
							else
								# If the request failed to generate a response, it was an internal server error:
								write_response(@version, 500, {}, nil)
							end
							
							# Gracefully finish reading the request body if it was not already done so.
							request&.finish
							
							# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
							task.yield
						end
					end
				end
			end
		end
	end
end
