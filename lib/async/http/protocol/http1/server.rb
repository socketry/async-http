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

require 'http/protocol/http11/connection'
require_relative '../http1/connection'

module Async
	module HTTP
		module Protocol
			module HTTP1
				module Server
					def next_request
						# The default is true.
						return nil unless @persistent
						
						request = Request.new(self)
						
						unless persistent?(request.headers)
							@persistent = false
						end
						
						return request
					rescue
						# Bad Request
						write_response(self.version, 400, {}, nil)
						
						raise
					end
					
					# Server loop.
					def each(task: Task.current)
						while request = next_request
							response = yield(request, self)
							
							return if @stream.closed?
							
							if response
								write_response(self.version, response.status, response.headers, response.body, request.head?)
							else
								# If the request failed to generate a response, it was an internal server error:
								write_response(self.version, 500, {}, nil)
							end
							
							# Gracefully finish reading the request body if it was not already done so.
							request.finish
							
							# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
							task.yield
						end
					end
				end
			end
		end
	end
end
