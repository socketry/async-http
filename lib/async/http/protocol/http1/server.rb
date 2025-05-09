# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2020, by Igor Sidorov.
# Copyright, 2023, by Thomas Morgan.
# Copyright, 2024, by Anton Zhuravsky.
# Copyright, 2025, by Jean Boussier.

require_relative "connection"
require_relative "finishable"

require "console/event/failure"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Server < Connection
					def initialize(...)
						super
						
						@ready = Async::Notification.new
					end
					
					def closed(error = nil)
						super
						
						@ready.signal
					end
					
					def fail_request(status)
						@persistent = false
						write_response(@version, status, {})
						write_body(@version, nil)
					rescue => error
						# At this point, there is very little we can do to recover:
						Console.debug(self, "Failed to write failure response!", error)
					end
					
					def next_request
						if closed?
							return nil
						elsif !idle?
							@ready.wait
						end
						
						# Read an incoming request:
						return unless request = Request.read(self)
						
						unless persistent?(request.version, request.method, request.headers)
							@persistent = false
						end
						
						return request
					rescue ::Protocol::HTTP1::BadRequest
						fail_request(400)
						# Conceivably we could retry here, but we don't really know how bad the error is, so it's better to just fail:
						raise
					end
					
					# Server loop.
					def each(task: Task.current)
						task.annotate("Reading #{self.version} requests for #{self.class}.")
						
						while request = next_request
							if body = request.body
								finishable = Finishable.new(body)
								request.body = finishable
							end
							
							response = yield(request, self)
							version = request.version
							body = response&.body
							
							if hijacked?
								body&.close
								return
							end
							
							task.defer_stop do
								# If a response was generated, send it:
								if response
									trailer = response.headers.trailer!
									
									# Some operations in this method are long running, that is, it's expected that `body.call(stream)` could literally run indefinitely. In order to facilitate garbage collection, we want to nullify as many local variables before calling the streaming body. This ensures that the garbage collection can clean up as much state as possible during the long running operation, so we don't retain objects that are no longer needed.
									
									if body and protocol = response.protocol
										# We force a 101 response if the protocol is upgraded - HTTP/2 CONNECT will return 200 for success, but this won't be understood by HTTP/1 clients:
										write_response(@version, 101, response.headers)
										
										# At this point, the request body is hijacked, so we don't want to call #finish below.
										request = nil
										response = nil
										
										if body.stream?
											return body.call(write_upgrade_body(protocol))
										else
											write_upgrade_body(protocol, body)
										end
									elsif response.status == 101
										# This code path is to support legacy behavior where the response status is set to 101, but the protocol is not upgraded. This may not be a valid use case, but it is supported for compatibility. We expect the response headers to contain the `upgrade` header.
										write_response(@version, response.status, response.headers)
										
										# Same as above:
										request = nil
										response = nil
										
										if body.stream?
											return body.call(write_tunnel_body(version))
										else
											write_tunnel_body(version, body)
										end
									else
										write_response(@version, response.status, response.headers)
										
										if request.connect? and response.success?
											# Same as above:
											request = nil
											response = nil
											
											if body.stream?
												return body.call(write_tunnel_body(version))
											else
												write_tunnel_body(version, body)
											end
										else
											head = request.head?
											
											# Same as above:
											request = nil
											response = nil
											
											write_body(version, body, head, trailer)
										end
									end
									
									# We are done with the body:
									body = nil
								else
									# If the request failed to generate a response, it was an internal server error:
									write_response(@version, 500, {})
									write_body(version, nil)
									
									request&.finish
								end
								
								if finishable
									finishable.wait(@persistent)
								else
									# Do not remove this line or you will unleash the gods of concurrency hell.
									task.yield
								end
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
