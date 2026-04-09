# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.

require "async"
require "io/endpoint"
require "protocol/http/middleware"

require_relative "protocol"

module Async
	module HTTP
		# An HTTP server that accepts connections on a specific endpoint and dispatches requests to an application handler.
		class Server < ::Protocol::HTTP::Middleware
			# Create a server using a block as the application handler.
			# @parameter arguments [Array] Arguments to pass to {initialize}.
			# @parameter options [Hash] Options to pass to {initialize}.
			def self.for(*arguments, **options, &block)
				self.new(block, *arguments, **options)
			end
			
			# Initialize the server with an application handler and endpoint.
			# @parameter app [Protocol::HTTP::Middleware] The Rack-compatible application to serve.
			# @parameter endpoint [Endpoint] The endpoint to bind to.
			# @parameter protocol [Protocol] The protocol to use for incoming connections.
			# @parameter scheme [String] The default scheme to set on requests.
			def initialize(app, endpoint, protocol: endpoint.protocol, scheme: endpoint.scheme)
				super(app)
				
				@endpoint = endpoint
				@protocol = protocol
				@scheme = scheme
			end
			
			# @returns [Hash] A JSON-compatible representation of this server.
			def as_json(...)
				{
					endpoint: @endpoint.to_s,
					protocol: @protocol,
					scheme: @scheme,
				}
			end
			
			# @returns [String] A JSON string representation of this server.
			def to_json(...)
				as_json.to_json(...)
			end
			
			attr :endpoint
			attr :protocol
			attr :scheme
			
			# Accept an incoming connection and process requests.
			# @parameter peer [IO] The connected peer.
			# @parameter address [Addrinfo] The remote address of the peer.
			def accept(peer, address, task: Task.current)
				connection = @protocol.server(peer)
				
				Console.debug(self){"Incoming connnection from #{address.inspect} to #{@protocol}"}
				
				connection.each do |request|
					# We set the default scheme unless it was otherwise specified.
					# https://tools.ietf.org/html/rfc7230#section-5.5
					request.scheme ||= self.scheme
					
					# Console.debug(self) {"Incoming request from #{address.inspect}: #{request.method} #{request.path}"}
					
					# If this returns nil, we assume that the connection has been hijacked.
					self.call(request)
				end
			rescue Protocol::HTTP::BadRequest
				# Ignore bad requests, just close the connection.
			ensure
				connection&.close
			end
			
			# @returns [Async::Task] The task that is running the server.
			def run
				Async do |task|
					@endpoint.accept(&self.method(:accept))
					
					# Wait for all children to finish:
					task.children.each(&:wait)
				end
			end
		end
	end
end
