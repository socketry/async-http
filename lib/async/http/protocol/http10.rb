# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

require_relative 'http1'

module Async
	module HTTP
		module Protocol
			module HTTP10
				VERSION = "HTTP/1.0"
				
				def self.bidirectional?
					false
				end
				
				def self.trailer?
					false
				end
				
				def self.client(peer)
					stream = IO::Stream.new(peer, sync: true)
					
					return HTTP1::Client.new(stream, VERSION)
				end
				
				def self.server(peer)
					stream = IO::Stream.new(peer, sync: true)
					
					return HTTP1::Server.new(stream, VERSION)
				end
				
				def self.names
					["http/1.0"]
				end
			end
		end
	end
end
