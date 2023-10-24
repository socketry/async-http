# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative '../response'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Response < Protocol::Response
					def self.read(connection, request)
						if parts = connection.read_response(request.method)
							self.new(connection, *parts)
						end
					end
					
					UPGRADE = 'upgrade'

          # @attribute [String] The HTTP response line reason.
					attr :reason

					# @parameter reason [String] HTTP response line reason phrase
					def initialize(connection, version, status, reason, headers, body)
						@connection = connection
						@reason = reason
						
						protocol = headers.delete(UPGRADE)
						
						super(version, status, headers, body, protocol)
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
