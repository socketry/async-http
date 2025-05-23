# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.

require "async"
require "io/endpoint"
require "protocol/http/middleware"
require "traces/provider"

require_relative "protocol"

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
			
			def as_json(...)
				{
					endpoint: @endpoint.to_s,
					protocol: @protocol,
					scheme: @scheme,
				}
			end
			
			def to_json(...)
				as_json.to_json(...)
			end
			
			attr :endpoint
			attr :protocol
			attr :scheme
			
			def accept(peer, address, task: Task.current)
				connection = @protocol.server(peer)
				
				Console.debug(self) {"Incoming connnection from #{address.inspect} to #{@protocol}"}
				
				connection.each do |request|
					# We set the default scheme unless it was otherwise specified.
					# https://tools.ietf.org/html/rfc7230#section-5.5
					request.scheme ||= self.scheme
					
					# Console.debug(self) {"Incoming request from #{address.inspect}: #{request.method} #{request.path}"}
					
					# If this returns nil, we assume that the connection has been hijacked.
					self.call(request)
				end
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
			
			Traces::Provider(self) do
				def call(request)
					if trace_parent = request.headers["traceparent"]
						Traces.trace_context = Traces::Context.parse(trace_parent.join, request.headers["tracestate"], remote: true)
					end
					
					attributes = {
						'http.version': request.version,
						'http.method': request.method,
						'http.authority': request.authority,
						'http.scheme': request.scheme,
						'http.path': request.path,
						'http.user_agent': request.headers["user-agent"],
					}
					
					if length = request.body&.length
						attributes["http.request.length"] = length
					end
					
					if protocol = request.protocol
						attributes["http.protocol"] = protocol
					end
					
					Traces.trace("async.http.server.call", resource: "#{request.method} #{request.path}", attributes: attributes) do |span|
						super.tap do |response|
							if status = response&.status
								span["http.status_code"] = status
							end
							
							if length = response&.body&.length
								span["http.response.length"] = length
							end
						end
					end
				end
			end
		end
	end
end
