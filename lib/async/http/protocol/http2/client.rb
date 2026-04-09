# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require_relative "connection"
require_relative "response"

require "protocol/http2/client"

module Async
	module HTTP
		module Protocol
			module HTTP2
				# An HTTP/2 client connection that sends requests and reads responses.
				class Client < ::Protocol::HTTP2::Client
					include Connection
					
					# Initialize the HTTP/2 client with an IO stream.
					# @parameter stream [IO::Stream] The underlying stream.
					def initialize(stream)
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(@stream)
						
						super(framer)
					end
					
					# Create a new response stream for the next request.
					# @returns [Response] The response object to be populated.
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
					
					# Write a request to the remote server via the given response stream.
					# @parameter response [Response] The response stream to write through.
					# @parameter request [Protocol::HTTP::Request] The request to send.
					def write_request(response, request)
						response.send_request(request)
					end
					
					# Wait for the response headers to arrive.
					# @parameter response [Response] The response to wait on.
					def read_response(response)
						response.wait
					end
				end
			end
		end
	end
end
