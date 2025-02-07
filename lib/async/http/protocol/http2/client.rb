# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require_relative "connection"
require_relative "response"

require "traces/provider"
require "protocol/http2/client"

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Client < ::Protocol::HTTP2::Client
					include Connection
					
					def initialize(stream)
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(@stream)
						
						super(framer)
					end
					
					def create_response
						Response::Stream.create(self, self.next_stream_id).response
					end
					
					# Used by the client to send requests to the remote server.
					def call(request)
						raise ::Protocol::HTTP2::Error, "Connection closed!" if self.closed?
						
						response = create_response
						write_request(response, request)
						read_response(response)
						
						return response
					end
					
					def write_request(response, request)
						response.send_request(request)
					end
					
					def read_response(response)
						response.wait
					end
					
					Traces::Provider(self) do
						def write_request(...)
							Traces.trace("async.http.protocol.http2.client.write_request") do
								super
							end
						end
						
						def read_response(...)
							Traces.trace("async.http.protocol.http2.client.read_response") do
								super
							end
						end
					end
				end
			end
		end
	end
end
