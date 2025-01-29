# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require_relative "../request"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Request < Protocol::Request
					def self.valid_path?(target)
						if target.start_with?("/")
							return true
						elsif target == '*'
							return true
						else
							return false
						end
					end
					
					URI_PATTERN = %r{\A(?<scheme>[^:/]+)://(?<authority>[^/]+)(?<path>.*)\z}
					
					def self.read(connection)
						connection.read_request do |authority, method, target, version, headers, body|
							if method == ::Protocol::HTTP::Methods::CONNECT
								# We put the target into the authority field for CONNECT requests, as per HTTP/2 semantics.
								self.new(connection, nil, target, method, nil, version, headers, body)
							elsif valid_path?(target)
								# This is a valid request.
								self.new(connection, nil, authority, method, target, version, headers, body)
							elsif match = target.match(URI_PATTERN)
								# We map the incoming absolute URI target to the scheme, authority, and path fields of the request.
								self.new(connection, match[:scheme], match[:authority], method, match[:path], version, headers, body)
							else
								# This is an invalid request.
								raise ::Protocol::HTTP1::BadRequest.new("Invalid request target: #{target}")
							end
						end
					end
					
					UPGRADE = "upgrade"
					
					def initialize(connection, scheme, authority, method, path, version, headers, body)
						@connection = connection
						
						# HTTP/1 requests with an upgrade header (which can contain zero or more values) are extracted into the protocol field of the request, and we expect a response to select one of those protocols with a status code of 101 Switching Protocols.
						protocol = headers.delete("upgrade")
						
						super(scheme, authority, method, path, version, headers, body, protocol, self.public_method(:write_interim_response))
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
					
					def write_interim_response(status, headers = nil)
						@connection.write_interim_response(@version, status, headers)
					end
				end
			end
		end
	end
end
