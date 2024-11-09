# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

module Async
	module HTTP
		module Protocol
			# Provide a well defined, cached representation of a peer (address).
			class Peer
				def self.for(io)
					if address = io.remote_address
						return new(address)
					end
				end
				
				def initialize(address)
					@address = address
					
					if address.ip?
						@ip_address = @address.ip_address
					end
				end
				
				attr :address
				attr :ip_address
				
				alias remote_address address
			end
		end
	end
end
