# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../protocol"

require "async/queue"

module Async
	module HTTP
		module Mock
			# This is an endpoint which bridges a client with a local server.
			class Endpoint
				def initialize(protocol = Protocol::HTTP2, scheme = "http", authority = "localhost", queue: Queue.new)
					@protocol = protocol
					@scheme = scheme
					@authority = authority
					
					@queue = queue
				end
				
				attr :protocol
				attr :scheme
				attr :authority
				
				# Processing incoming connections
				# @yield [::HTTP::Protocol::Request] the requests as they come in.
				def run(parent: Task.current, &block)
					while peer = @queue.dequeue
						server = @protocol.server(peer)
						
						parent.async do
							server.each(&block)
						end
					end
				end
				
				def connect
					local, remote = ::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@queue.enqueue(remote)
					
					return local
				end
				
				def wrap(endpoint)
					self.class.new(@protocol, endpoint.scheme, endpoint.authority, queue: @queue)
				end
			end
		end
	end
end
