# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative '../request'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Request < Protocol::Request
					def self.read(connection)
						if parts = connection.read_request
							self.new(connection, *parts)
						end
					end

					UPGRADE = 'upgrade'
					
					def initialize(connection, authority, method, path, version, headers, body)
						@connection = connection
						
						# HTTP/1 requests with an upgrade header (which can contain zero or more values) are extracted into the protocol field of the request, and we expect a response to select one of those protocols with a status code of 101 Switching Protocols.
						protocol = headers.delete('upgrade')
						
						super(nil, authority, method, path, version, headers, body, protocol)
					end
					
					def connection
						@connection
					end
					
					def hijack?
						true
					end
					
					def hijack!
						@connection.hijack!
					end
					
					def write_interim_response(response)
						@connection.write_interim_response(response.version, response.status, response.headers)
					end
				end
			end
		end
	end
end
