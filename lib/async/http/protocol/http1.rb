# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2024, by Thomas Morgan.

require_relative "http1/client"
require_relative "http1/server"

require "io/stream"

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
					stream = ::IO::Stream(peer)
					
					return HTTP1::Client.new(stream, VERSION)
				end
				
				def self.server(peer)
					stream = ::IO::Stream(peer)
					
					return HTTP1::Server.new(stream, VERSION)
				end
				
				def self.names
					["http/1.1", "http/1.0"]
				end
			end
		end
	end
end
