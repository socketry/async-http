# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.

require_relative 'http1'

module Async
	module HTTP
		module Protocol
			module HTTP11
				VERSION = "HTTP/1.1"
				
				def self.bidirectional?
					true
				end
				
				def self.trailer?
					true
				end
				
				def self.client(peer)
					return HTTP1::Client.new(peer, VERSION)
				end
				
				def self.server(peer)
					return HTTP1::Server.new(peer, VERSION)
				end
				
				def self.names
					["http/1.1"]
				end
			end
		end
	end
end
