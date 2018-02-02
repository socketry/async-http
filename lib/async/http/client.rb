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
		class Client
			def initialize(endpoints, protocol_class = Protocol::HTTP11)
				@endpoints = endpoints
				
				@protocol_class = protocol_class
			end
			
			GET = 'GET'.freeze
			HEAD = 'HEAD'.freeze
			POST = 'POST'.freeze
			
			def get(path, *args)
				connect do |protocol|
					protocol.send_request(GET, path, *args)
				end
			end
			
			def head(path, *args)
				connect do |protocol|
					protocol.send_request(HEAD, path, *args)
				end
			end
			
			def post(path, *args)
				connect do |protocol|
					protocol.send_request(POST, path, *args)
				end
			end
			
			def send_request(*args)
				connect do |protocol|
					protocol.send_request(*args)
				end
			end
			
			private
			
			def connect
				Async::IO::Endpoint.each(@endpoints) do |endpoint|
					# puts "Connecting to #{address} on process #{Process.pid}"
					
					endpoint.connect do |peer|
						stream = Async::IO::Stream.new(peer)
						
						# We only yield for first successful connection.
						
						return yield @protocol_class.new(stream)
					end
				end
			end
		end
	end
end
