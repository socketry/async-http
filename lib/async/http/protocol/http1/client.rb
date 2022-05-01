# frozen_string_literal: true
#
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
						# We need to keep track of connections which are not in the initial "ready" state.
						@ready = false
						
						Console.logger.debug(self) {"#{request.method} #{request.path} #{request.headers.inspect}"}
						
						# Mark the start of the trailers:
						trailer = request.headers.trailer!
						
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
								# This is a very tricky apect of handling HTTP/1 upgrade connections. In theory, this approach is a bit inefficient, because we spin up a task just to handle writing to the underlying stream when we could be writing to the stream directly. But we need to maintain some level of compatibility with HTTP/2. Additionally, we don't know if the upgrade request will be accepted, so starting to write the body at this point needs to be handled with care.
								task.async do |subtask|
									subtask.annotate("Upgrading request.")
									
									# If this fails, this connection will be closed.
									write_upgrade_body(protocol, body)
								end
							elsif request.connect?
								task.async do |subtask|
									subtask.annotate("Tunnelling body.")
									
									write_tunnel_body(@version, body)
								end
							else
								task.async do |subtask|
									subtask.annotate("Streaming body.")
									
									# Once we start writing the body, we can't recover if the request fails. That's because the body might be generated dynamically, streaming, etc.
									write_body(@version, body, false, trailer)
								end
							end
						elsif protocol = request.protocol
							write_upgrade_body(protocol)
						else
							write_body(@version, body, false, trailer)
						end
						
						response = Response.read(self, request)
						@ready = true
						
						return response
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
