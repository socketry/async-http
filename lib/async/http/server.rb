# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.

require 'async/io/endpoint'
require 'async/io/stream'

require 'protocol/http/middleware'

require 'traces/provider'

require_relative 'protocol'

module Async
	module HTTP
		class Server < ::Protocol::HTTP::Middleware
			def self.for(*arguments, **options, &block)
				self.new(block, *arguments, **options)
			end
			
			def initialize(app, endpoint, protocol: endpoint.protocol, scheme: endpoint.scheme)
				super(app)
				
				@endpoint = endpoint
				@protocol = protocol
				@scheme = scheme
			end
			
			attr :endpoint
			attr :protocol
			attr :scheme
			
			def accept(peer, address, task: Task.current)
				connection = @protocol.server(peer)
				
				Console.logger.debug(self) {"Incoming connnection from #{address.inspect} to #{@protocol}"}
				
				connection.each do |request|
					# We set the default scheme unless it was otherwise specified.
					# https://tools.ietf.org/html/rfc7230#section-5.5
					request.scheme ||= self.scheme
					
					# This is a slight optimization to avoid having to get the address from the socket.
					request.remote_address = address
					
					# Console.logger.debug(self) {"Incoming request from #{address.inspect}: #{request.method} #{request.path}"}
					
					# If this returns nil, we assume that the connection has been hijacked.
					self.call(request)
				end
			ensure
				connection&.close
			end
			
			def run
				@endpoint.accept(&self.method(:accept))
			end
			
			Traces::Provider(self) do
				def call(request)
					if trace_parent = request.headers['traceparent']
						self.trace_context = Traces::Context.parse(trace_parent.join, request.headers['tracestate'], remote: true)
					end
					
					attributes = {
						'http.method': request.method,
						'http.authority': request.authority,
						'http.scheme': request.scheme,
						'http.path': request.path,
						'http.user_agent': request.headers['user-agent'],
					}
					
					if length = request.body&.length
						attributes['http.request.length'] = length
					end
					
					if protocol = request.protocol
						attributes['http.protocol'] = protocol
					end
					
					trace('async.http.server.call', resource: "#{request.method} #{request.path}", attributes: attributes) do |span|
						super.tap do |response|
							if status = response&.status
								span['http.status_code'] = status
							end
							
							if length = response&.body&.length
								span['http.response.length'] = length
							end
						end
					end
				end
			end
		end
	end
end
