# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module HTTP
		module Protocol
			# A protocol wrapper that forwards pre-configured options to client and server creation.
			class Configured
				# Initialize with a protocol and options.
				# @parameter protocol [Protocol] The underlying protocol to configure.
				# @parameter options [Hash] Options to forward to client and server creation.
				def initialize(protocol, **options)
					@protocol = protocol
					@options = options
				end
				
				# @attribute [Protocol] The underlying protocol.
				attr :protocol
				
				# @attribute [Hash] The options to pass to the protocol.
				attr :options
				
				# Create a client connection using the configured protocol options.
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Additional options merged with the configured defaults.
				def client(peer, **options)
					options = @options.merge(options)
					@protocol.client(peer, **options)
				end
				
				# Create a server connection using the configured protocol options.
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Additional options merged with the configured defaults.
				def server(peer, **options)
					options = @options.merge(options)
					@protocol.server(peer, **options)
				end
				
				# @returns [Array(String)] The protocol names from the underlying protocol.
				def names
					@protocol.names
				end
			end
			
			# Provides a `new` method that creates a {Configured} wrapper, allowing protocols to be instantiated with custom options.
			module Configurable
				# Create a new {Configured} instance wrapping this protocol with the given options.
				# @parameter options [Hash] Configuration options for client and server creation.
				# @returns [Configured] A configured protocol instance.
				def new(**options)
					Configured.new(self, **options)
				end
			end
		end
	end
end
