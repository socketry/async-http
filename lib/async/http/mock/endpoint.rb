# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../protocol"

require "async/queue"

module Async
	module HTTP
		# @namespace
		module Mock
			# This is an endpoint which bridges a client with a local server.
			class Endpoint
				# Initialize a mock endpoint for testing.
				# @parameter protocol [Protocol] The protocol to use for connections.
				# @parameter scheme [String] The URL scheme.
				# @parameter authority [String] The hostname authority.
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
				
				# Create a new client-side connection by enqueuing the server-side socket.
				# @returns [Socket] The client-side socket.
				def connect
					local, remote = ::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@queue.enqueue(remote)
					
					return local
				end
				
				# Create a new mock endpoint that shares the same connection queue but adopts another endpoint's scheme and authority.
				# @parameter endpoint [Endpoint] The endpoint to mirror the scheme and authority from.
				# @returns [Endpoint] A new mock endpoint.
				def wrap(endpoint)
					self.class.new(@protocol, endpoint.scheme, endpoint.authority, queue: @queue)
				end
			end
		end
	end
end
