# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/io/endpoint'

require_relative 'protocol'

module Async
	module HTTP
		class Server
			def initialize(endpoint, protocol_class = Protocol::HTTP1)
				@endpoint = endpoint
				@protocol_class = protocol_class
			end
			
			def handle_request(request, peer, address)
				[200, {"Content-Type" => "text/plain"}, ["Hello World"]]
			end
			
			def accept(peer, address)
				stream = Async::IO::Stream.new(peer)
				protocol = @protocol_class.server(stream)
				
				Async.logger.debug(self) {"Incoming connnection from #{address.inspect}"}
				
				hijack = catch(:hijack) do
					protocol.receive_requests do |request|
						Async.logger.debug(self) {"Incoming request from #{address.inspect}: #{request.method} #{request.path}"}
						handle_request(request, peer, address)
					end
				end

				if hijack
					hijack.call
				end
			rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
				# Sometimes client will disconnect without completing a result or reading the entire buffer.
				return nil
			ensure
				peer.close
			end
			
			def run
				@endpoint.accept(&self.method(:accept))
			end
		end
	end
end
