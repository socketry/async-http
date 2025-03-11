# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2024, by Thomas Morgan.

require_relative "configurable"

require_relative "http1/client"
require_relative "http1/server"

require "io/stream"

module Async
	module HTTP
		module Protocol
			module HTTP1
				extend Configurable
				
				VERSION = "HTTP/1.1"
				
				# @returns [Boolean] Whether the protocol supports bidirectional communication.
				def self.bidirectional?
					true
				end
				
				# @returns [Boolean] Whether the protocol supports trailers.
				def self.trailer?
					true
				end
				
				# Create a client for an outbound connection.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the client instance.
				def self.client(peer, **options)
					stream = ::IO::Stream(peer)
					
					return HTTP1::Client.new(stream, VERSION, **options)
				end
				
				# Create a server for an inbound connection.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the server instance.
				def self.server(peer, **options)
					stream = ::IO::Stream(peer)
					
					return HTTP1::Server.new(stream, VERSION, **options)
				end
				
				# @returns [Array] The names of the supported protocol.
				def self.names
					["http/1.1", "http/1.0"]
				end
			end
		end
	end
end
