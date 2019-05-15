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
				class Client < Connection
					# Used by the client to send requests to the remote server.
					def call(request, task: Task.current)
						Async.logger.debug(self) {"#{request.method} #{request.path} #{request.headers.inspect}"}
						
						# We carefully interpret https://tools.ietf.org/html/rfc7230#section-6.3.1 to implement this correctly.
						begin
							write_request(request.authority, request.method, request.path, @version, request.headers)
						rescue
							# If we fail to fully write the request and body, we can retry this request.
							raise RequestFailed
						end
						
						if request.body?
							body = request.body
							
							if protocol = request.protocol
								stream = write_upgrade_body(protocol)
								body.call(stream)
							else
								task.async do
									# Once we start writing the body, we can't recover if the request fails. That's because the body might be generated dynamically, streaming, etc.
									write_body(@version, body)
								end
							end
						else
							write_empty_body(request.body)
						end
						
						# This won't return the response until the entire body is written.
						return Response.new(self, request)
					rescue
						# This will ensure that #reusable? returns false.
						@stream.close
						
						raise
					end
				end
			end
		end
	end
end
