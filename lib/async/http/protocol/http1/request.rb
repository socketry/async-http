# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require_relative "../request"

module Async
	module HTTP
		module Protocol
			module HTTP1
				# An incoming HTTP/1 request parsed from the connection.
				class Request < Protocol::Request
					# Check whether the given request target is a valid path.
					# @parameter target [String] The request target to validate.
					# @returns [Boolean] Whether the target is a valid path.
					def self.valid_path?(target)
						if target.start_with?("/")
							return true
						elsif target == "*"
							return true
						else
							return false
						end
					end
					
					URI_PATTERN = %r{\A(?<scheme>[^:/]+)://(?<authority>[^/]+)(?<path>.*)\z}
					
					# Read and parse the next request from the connection.
					# @parameter connection [Connection] The HTTP/1 connection to read from.
					# @returns [Request | Nil] The parsed request, or `nil` if the connection is closed.
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
					
					# Initialize the request from the parsed components.
					# @parameter connection [Connection] The underlying connection.
					# @parameter scheme [String | Nil] The request scheme.
					# @parameter authority [String | Nil] The request authority.
					# @parameter method [String] The HTTP method.
					# @parameter path [String | Nil] The request path.
					# @parameter version [String] The HTTP version.
					# @parameter headers [Protocol::HTTP::Headers] The request headers.
					# @parameter body [Protocol::HTTP::Body::Readable | Nil] The request body.
					def initialize(connection, scheme, authority, method, path, version, headers, body)
						@connection = connection
						
						# HTTP/1 requests with an upgrade header (which can contain zero or more values) are extracted into the protocol field of the request, and we expect a response to select one of those protocols with a status code of 101 Switching Protocols.
						protocol = headers.delete("upgrade")
						
						super(scheme, authority, method, path, version, headers, body, protocol, self.public_method(:write_interim_response))
					end
					
					# @returns [Connection] The underlying HTTP/1 connection.
					def connection
						@connection
					end
					
					# @returns [Boolean] Whether connection hijacking is supported.
					def hijack?
						true
					end
					
					# Hijack the underlying connection for bidirectional communication.
					def hijack!
						@connection.hijack!
					end
					
					# Write an interim (1xx) response to the client.
					# @parameter status [Integer] The interim HTTP status code.
					# @parameter headers [Hash | Nil] Optional interim response headers.
					def write_interim_response(status, headers = nil)
						@connection.write_interim_response(@version, status, headers)
					end
				end
			end
		end
	end
end
