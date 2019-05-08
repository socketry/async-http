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
require_relative 'promise'

require 'protocol/http2/server'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Server < ::Protocol::HTTP2::Server
					include Connection
					
					def initialize(stream)
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(stream)
						
						super(framer)
						
						@requests = Async::Queue.new
					end
					
					attr :requests
					
					def create_stream(stream_id)
						request = Request.new(self, stream_id)
						
						return request.stream
					end
					
					def stop_connection(error)
						super
						
						@requests.enqueue nil
					end
					
					def each
						while request = @requests.dequeue
							@count += 1
							
							# We need to close the stream if the user code blows up while generating a response:
							response = begin
								response = yield(request)
							rescue
								request.stream.send_reset_stream(::Protocol::HTTP2::INTERNAL_ERROR)
								
								Async.logger.error(request) {$!}
							else
								request.send_response(response)
							end
						end
					end
				end
			end
		end
	end
end
