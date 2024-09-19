# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2023, by Josh Huber.

require_relative "../response"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Response < Protocol::Response
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
					
					def pool=(pool)
						if @connection.idle? or @connection.closed?
							pool.release(@connection)
						else
							@connection.pool = pool
						end
					end
					
					def connection
						@connection
					end
					
					def hijack?
						@body.nil?
					end
					
					def hijack!
						@connection.hijack!
					end
				end
			end
		end
	end
end
