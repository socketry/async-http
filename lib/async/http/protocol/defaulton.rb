# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module HTTP
		module Protocol
			# This module provides a default instance of the protocol, which can be used to create clients and servers. The name is a play on "Default" + "Singleton".
			module Defaulton
				def self.extended(base)
					base.instance_variable_set(:@default, base.new)
				end
				
				attr_accessor :default
				
				# Create a client for an outbound connection, using the default instance.
				def client(peer, **options)
					default.client(peer, **options)
				end
				
				# Create a server for an inbound connection, using the default instance.
				def server(peer, **options)
					default.server(peer, **options)
				end
				
				# @returns [Array] The names of the supported protocol, used for Application Layer Protocol Negotiation (ALPN), using the default instance.
				def names
					default.names
				end
			end
			
			private_constant :Defaulton
		end
	end
end
