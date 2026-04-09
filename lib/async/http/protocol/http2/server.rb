# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require_relative "connection"
require_relative "request"

require "protocol/http2/server"

module Async
	module HTTP
		module Protocol
			module HTTP2
				# An HTTP/2 server connection that receives requests and sends responses.
				class Server < ::Protocol::HTTP2::Server
					include Connection
					
					# Initialize the HTTP/2 server with an IO stream.
					# @parameter stream [IO::Stream] The underlying stream.
					def initialize(stream)
						# Used by some generic methods in Connetion:
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(stream)
						
						super(framer)
						
						@requests = Async::Queue.new
					end
					
					attr :requests
					
					# Accept a new stream from a client.
					# @parameter stream_id [Integer] The stream ID assigned by the client.
					def accept_stream(stream_id)
						super do
							Request::Stream.create(self, stream_id)
						end
					end
					
					# Close the server connection and stop accepting requests.
					def close(error = nil)
						if @requests
							# Stop the request loop:
							@requests.enqueue(nil)
							@requests = nil
						end
						
						super
					end
					
					# Enumerate incoming requests, yielding each one for processing.
					# @yields {|request| ...} Each incoming request.
					# 	@parameter request [Request] The incoming HTTP/2 request.
					def each(task: Task.current)
						task.annotate("Reading #{version} requests for #{self.class}.")
						
						# It's possible the connection has died before we get here...
						@requests&.async do |task, request|
							task.annotate("Incoming request: #{request.method} #{request.path.inspect}.")
							
							task.defer_stop do
								response = yield(request)
							rescue
								# We need to close the stream if the user code blows up while generating a response:
								request.stream.send_reset_stream(::Protocol::HTTP2::INTERNAL_ERROR)
								
								raise
							else
								request.send_response(response)
							end
						end
						
						# Maybe we should add some synchronisation here - i.e. only exit once all requests are finished.
					end
				end
			end
		end
	end
end
