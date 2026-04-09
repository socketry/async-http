# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

require "protocol/http/response"

require_relative "../body/writable"

module Async
	module HTTP
		module Protocol
			# An HTTP response received from a server via client protocol implementations.
			class Response < ::Protocol::HTTP::Response
				# @returns [Connection | Nil] The underlying protocol connection.
				def connection
					nil
				end
				
				# @returns [Boolean] Whether this response supports connection hijacking.
				def hijack?
					false
				end
				
				# @returns [Protocol::HTTP::Peer | Nil] The peer associated with this connection.
				def peer
					self.connection&.peer
				end
				
				# @returns [Addrinfo | Nil] The remote address of the peer.
				def remote_address
					self.peer&.remote_address
				end
				
				# @returns [String] A string representation of the response.
				def inspect
					"#<#{self.class}:0x#{self.object_id.to_s(16)} status=#{status}>"
				end
			end
		end
	end
end
