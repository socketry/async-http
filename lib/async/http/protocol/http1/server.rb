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
						
						unless persistent?(request.version, request.method, request.headers)
							@persistent = false
						end
						
						return request
					rescue Async::TimeoutError
						# For an interesting discussion about this behaviour, see https://trac.nginx.org/nginx/ticket/1005
						# If you enable this, you will see some spec failures...
						# fail_request(408)
						raise
					rescue
						fail_request(400)
						raise
					end
					
					# Server loop.
					def each(task: Task.current)
						task.annotate("Reading #{self.version} requests for #{self.class}.")
						
						while request = next_request
							response = yield(request, self)
							body = response&.body
							
							if @stream.nil? and body.nil?
								# Full hijack.
								return
							end
							
							begin
								# If a response was generated, send it:
								if response
									trailer = response.headers.trailer!

									write_response(@version, response.status, response.headers)

									# Some operations in this method are long running, that is, it's expected that `body.call(stream)` could literally run indefinitely. In order to facilitate garbage collection, we want to nullify as many local variables before calling the streaming body. This ensures that the garbage collection can clean up as much state as possible during the long running operation, so we don't retain objects that are no longer needed.

									if body and protocol = response.protocol
										stream = write_upgrade_body(protocol)
										
										# At this point, the request body is hijacked, so we don't want to call #finish below.
										request = response = nil
										
										body.call(stream)
									elsif request.connect? and response.success?
										stream = write_tunnel_body(request.version)
										
										# Same as above:
										request = response = nil
										
										body.call(stream)
									else
										head = request.head?
										version = request.version
										
										# Same as above:
										request = nil unless body
										response = nil
										
										write_body(version, body, head, trailer)
									end

									# We are done with the body, you shouldn't need to call close on it:
									body = nil
								else
									# If the request failed to generate a response, it was an internal server error:
									write_response(@version, 500, {})
									write_body(request.version, nil)
								end
								
								# Gracefully finish reading the request body if it was not already done so.
								request&.finish
								
								# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
								task.yield
							rescue => error
								raise
							ensure
								body&.close(error)
							end
						end
					end
				end
			end
		end
	end
end
