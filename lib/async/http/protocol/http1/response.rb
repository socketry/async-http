# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2023, by Josh Huber.

require_relative "../response"

module Async
	module HTTP
		module Protocol
			module HTTP1
				# An HTTP/1 response received from a server.
				class Response < Protocol::Response
					# Read the response from the connection, handling interim responses.
					# @parameter connection [Connection] The HTTP/1 connection to read from.
					# @parameter request [Request] The original request.
					# @returns [Response | Nil] The final response.
					def self.read(connection, request)
						while parts = connection.read_response(request.method)
							response = self.new(connection, *parts)
							
							if response.final?
								return response
							else
								request.send_interim_response(response.status, response.headers)
							end
						end
					end
					
					UPGRADE = "upgrade"
					
					# @attribute [String] The HTTP response line reason.
					attr :reason
					
					# @parameter reason [String] HTTP response line reason phrase.
					def initialize(connection, version, status, reason, headers, body)
						@connection = connection
						@reason = reason
						
						# Technically, there should never be more than one value for the upgrade header, but we'll just take the first one to avoid complexity.
						protocol = headers.delete(UPGRADE)&.first
						
						super(version, status, headers, body, protocol)
					end
					
					# Assign the connection pool, releasing the connection if it is already idle or closed.
					# @parameter pool [Async::Pool::Controller] The connection pool.
					def pool=(pool)
						if @connection.idle? or @connection.closed?
							pool.release(@connection)
						else
							@connection.pool = pool
						end
					end
					
					# @returns [Connection] The underlying HTTP/1 connection.
					def connection
						@connection
					end
					
					# @returns [Boolean] Whether connection hijacking is available (when the body is `nil`).
					def hijack?
						@body.nil?
					end
					
					# Hijack the underlying connection for bidirectional communication.
					def hijack!
						@connection.hijack!
					end
				end
			end
		end
	end
end
