# frozen_string_literal: true
#
# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
