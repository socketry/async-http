# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2024, by Thomas Morgan.

require_relative 'http2/client'
require_relative 'http2/server'

require 'io/stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				VERSION = "HTTP/2"
				
				def self.bidirectional?
					true
				end
				
				def self.trailer?
					true
				end
				
				CLIENT_SETTINGS = {
					::Protocol::HTTP2::Settings::ENABLE_PUSH => 0,
					::Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 0x100000,
					::Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 0x800000,
				}
				
				SERVER_SETTINGS = {
					# We choose a lower maximum concurrent streams to avoid overloading a single connection/thread.
					::Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS => 128,
					::Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 0x100000,
					::Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 0x800000,
					::Protocol::HTTP2::Settings::ENABLE_CONNECT_PROTOCOL => 1,
				}
				
				def self.client(peer, settings = CLIENT_SETTINGS)
					stream = ::IO::Stream(peer)
					client = Client.new(stream)
					
					client.send_connection_preface(settings)
					client.start_connection
					
					return client
				end
				
				def self.server(peer, settings = SERVER_SETTINGS)
					stream = ::IO::Stream(peer)
					server = Server.new(stream)
					
					server.read_connection_preface(settings)
					server.start_connection
					
					return server
				end
				
				def self.names
					["h2"]
				end
			end
		end
	end
end
