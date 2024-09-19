# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require_relative "connection"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Client < Connection
					def initialize(...)
						super
						
						@pool = nil
					end
					
					attr_accessor :pool
					
					def closed!
						super
						
						if pool = @pool
							@pool = nil
							pool.release(self)
						end
					end
					
					# Used by the client to send requests to the remote server.
					def call(request, task: Task.current)
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
								task.async(annotation: "Upgrading request...") do
									# If this fails, this connection will be closed.
									write_upgrade_body(protocol, body)
								end
							elsif request.connect?
								task.async(annotation: "Tunnneling request...") do
									write_tunnel_body(@version, body)
								end
							else
								task.async(annotation: "Streaming request...") do
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
						
						return response
					rescue
						# This will ensure that #reusable? returns false.
						self.close
						
						raise
					end
				end
			end
		end
	end
end
