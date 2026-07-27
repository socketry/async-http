# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require_relative "request"
require_relative "response"

require "protocol/http1"
require "protocol/http/peer"
require "openssl"

module Async
	module HTTP
		module Protocol
			module HTTP1
				# An HTTP/1 connection that wraps an IO stream with version and state tracking.
				class Connection < ::Protocol::HTTP1::Connection
					# Initialize the connection with an IO stream and HTTP version.
					# @parameter stream [IO::Stream] The underlying stream.
					# @parameter version [String] The negotiated HTTP version string.
					# @parameter options [Hash] Additional options for the connection.
					def initialize(stream, version, **options)
						super(stream, **options)
						
						# On the client side, we need to send the HTTP version with the initial request. On the server side, there are some scenarios (bad request) where we don't know the request version. In those cases, we use this value, which is either hard coded based on the protocol being used, OR could be negotiated during the connection setup (e.g. ALPN).
						@version = version
					end
					
					# @returns [String] A string representation of this connection.
					def to_s
						"\#<#{self.class} negotiated #{@version}, #{@state}>"
					end
					
					# @returns [String] A JSON-compatible representation.
					def as_json(...)
						to_s
					end
					
					# @returns [String] A JSON string representation.
					def to_json(...)
						as_json.to_json(...)
					end
					
					attr :version
					
					# @returns [Boolean] Whether this is an HTTP/1 connection.
					def http1?
						true
					end
					
					# @returns [Boolean] Whether this is an HTTP/2 connection.
					def http2?
						false
					end
					
					# @returns [Protocol::HTTP::Peer] The peer information for this connection.
					def peer
						@peer ||= ::Protocol::HTTP::Peer.for(@stream.io)
					end
					
					attr :count
					
					# @returns [Integer] The maximum number of concurrent requests (always 1 for HTTP/1).
					def concurrency
						1
					end
					
					# Can we use this connection to make requests?
					def viable?
						unless self.idle?
							return false
						end
						
						unless @stream
							return false
						end
						
						# Application data on an idle HTTP/1 connection is unexpected. A
						# non-blocking peek also processes an EOF or TLS close notification.
						if @stream.peek_partial(1)
							return false
						end
						
						return @stream.readable?
					rescue => error
						Console.debug(self, "Connection viability probe failed!", exception: error)
						
						return false
					end
					
					# @returns [Boolean] Whether the connection can be reused for another request.
					def reusable?
						@persistent && @stream && !@stream.closed?
					end
				end
			end
		end
	end
end
