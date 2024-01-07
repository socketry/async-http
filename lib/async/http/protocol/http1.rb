# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

require_relative 'http1/client'
require_relative 'http1/server'

module Async
	module HTTP
		module Protocol
			module HTTP1
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
					["http/1.1", "http/1.0"]
				end
			end
		end
	end
end
