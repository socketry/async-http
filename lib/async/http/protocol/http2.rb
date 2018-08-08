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

require_relative 'http2/client'
require_relative 'http2/server'

module Async
	module HTTP
		module Protocol
			module HTTP2
				CLIENT_SETTINGS = {
					::HTTP::Protocol::HTTP2::Settings::ENABLE_PUSH => 0,
					::HTTP::Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS => 256,
					::HTTP::Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 0x100000,
					::HTTP::Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 0x7FFFFFFF,
				}
				
				SERVER_SETTINGS = {
					::HTTP::Protocol::HTTP2::Settings::ENABLE_PUSH => 0,
					# We choose a lower maximum concurrent streams to avoid overloading a single connection/thread.
					::HTTP::Protocol::HTTP2::Settings::MAXIMUM_CONCURRENT_STREAMS => 32,
					::HTTP::Protocol::HTTP2::Settings::MAXIMUM_FRAME_SIZE => 0x100000,
					::HTTP::Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => 0x7FFFFFFF,
				}
				
				def self.client(stream, settings = CLIENT_SETTINGS)
					client = Client.new(stream)
					
					client.send_connection_preface(settings)
					client.start_connection
					
					return client
				end
				
				def self.server(stream, settings = SERVER_SETTINGS)
					server = Server.new(stream)
					
					server.read_connection_preface(settings)
					server.start_connection
					
					return server
				end
			end
		end
	end
end
