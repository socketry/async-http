# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.

require_relative "defaulton"

require_relative "http10"
require_relative "http11"
require_relative "http2"

module Async
	module HTTP
		module Protocol
			# A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
			class HTTPS
				# The protocol classes for each supported protocol.
				HANDLERS = {
					"h2" => HTTP2,
					"http/1.1" => HTTP11,
					"http/1.0" => HTTP10,
					nil => HTTP11,
				}
				
				# Initialize the HTTPS protocol negotiator.
				# @parameter handlers [Hash] A mapping of ALPN protocol names to protocol classes.
				# @parameter options [Hash] Per-protocol options keyed by protocol class.
				def initialize(handlers = HANDLERS, **options)
					@handlers = handlers
					@options = options
				end
				
				# Register a protocol handler for a given ALPN protocol name.
				# @parameter name [String] The ALPN protocol name.
				# @parameter protocol [Class] The protocol class to handle connections.
				# @parameter options [Hash] Options to pass when creating client or server instances.
				def add(name, protocol, **options)
					@handlers[name] = protocol
					@options[protocol] = options
				end
				
				# Determine the protocol of the peer and return the appropriate protocol class.
				#
				# Use TLS Application Layer Protocol Negotiation (ALPN) to determine the protocol.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @returns [Class] The protocol class to use.
				def protocol_for(peer)
					# alpn_protocol is only available if openssl v1.0.2+
					name = peer.alpn_protocol
					
					Console.debug(self){"Negotiating protocol #{name.inspect}..."}
					
					if protocol = HANDLERS[name]
						return protocol
					else
						raise ArgumentError, "Could not determine protocol for connection (#{name.inspect})."
					end
				end
				
				# Create a client for an outbound connection.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the client instance.
				def client(peer, **options)
					protocol = protocol_for(peer)
					options = options[protocol] || {}
					
					protocol.client(peer, **options)
				end
				
				# Create a server for an inbound connection.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the server instance.
				def server(peer, **options)
					protocol = protocol_for(peer)
					options = options[protocol] || {}
					
					protocol.server(peer, **options)
				end
				
				# @returns [Array] The names of the supported protocol, used for Application Layer Protocol Negotiation (ALPN).
				def names
					@handlers.keys.compact
				end
				
				extend Defaulton
			end
		end
	end
end
