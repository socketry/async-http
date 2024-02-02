# frozen_string_literal: true
#
# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative '../protocol'

require 'async/queue'

module Async
	module HTTP
		module Mock
			# This is an endpoint which bridges a client with a local server.
			class Endpoint
				def initialize(protocol = Protocol::HTTP2, scheme = "http", authority = "localhost",  queue: Queue.new)
					@protocol = protocol
					@scheme = scheme
					@authority = authority
					
					@queue = queue
				end
				
				attr :protocol
				attr :scheme
				attr :authority
				
				# Processing incoming connections
				# @yield [::HTTP::Protocol::Request] the requests as they come in.
				def run(parent: Task.current, &block)
					while peer = @queue.dequeue
						stream = IO::Stream.new(peer, sync: false)
						
						server = @protocol.server(peer)
						
						parent.async do
							server.each(&block)
						end
					end
				end
				
				def connect
					local, remote = Async::IO::Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM)
					
					@queue.enqueue(remote)
					
					return local
				end
			end
		end
	end
end
