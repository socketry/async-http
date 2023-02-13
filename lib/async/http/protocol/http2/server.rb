# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative 'connection'
require_relative 'request'

require 'protocol/http2/server'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Server < ::Protocol::HTTP2::Server
					include Connection
					
					def initialize(stream)
						# Used by some generic methods in Connetion:
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(stream)
						
						super(framer)
						
						@requests = Async::Queue.new
					end
					
					attr :requests
					
					def accept_stream(stream_id)
						super do
							Request::Stream.create(self, stream_id)
						end
					end
					
					def close(error = nil)
						if @requests
							# Stop the request loop:
							@requests.enqueue(nil)
							@requests = nil
						end
						
						super
					end
					
					def each(task: Task.current)
						task.annotate("Reading #{version} requests for #{self.class}.")
						
						# It's possible the connection has died before we get here...
						@requests&.async do |task, request|
							task.annotate("Incoming request: #{request.method} #{request.path.inspect}.")
							
							@count += 1
							
							begin
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
