# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module HTTP
		module Protocol
			class Configured
				def initialize(protocol, **options)
					@protocol = protocol
					@options = options
				end
				
				# @attribute [Protocol] The underlying protocol.
				attr :protocol
				
				# @attribute [Hash] The options to pass to the protocol.
				attr :options
				
				def client(peer, **options)
					options = @options.merge(options)
					@protocol.client(peer, **options)
				end
				
				def server(peer, **options)
					options = @options.merge(options)
					@protocol.server(peer, **options)
				end
				
				def names
					@protocol.names
				end
			end
			
			module Configurable
				def new(**options)
					Configured.new(self, **options)
				end
			end
		end
	end
end
