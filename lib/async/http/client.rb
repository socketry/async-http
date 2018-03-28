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
			def initialize(endpoint, protocol = nil, authority = nil, **options)
				@endpoint = endpoint
				
				@protocol = protocol || endpoint.protocol
				@authority = authority || endpoint.hostname
				
				@connections = connect(**options)
			end
			
			attr :endpoint
			attr :protocol
			attr :authority
			
			def self.open(*args, &block)
				client = self.new(*args)
				
				return client unless block_given?
				
				begin
					yield client
				ensure
					client.close
				end
			end
			
			def close
				@connections.close
			end
			
			VERBS = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE']
			
			VERBS.each do |verb|
				define_method(verb.downcase) do |*args|
					self.request(verb, *args)
				end
			end
			
			def request(*args)
				@connections.acquire do |connection|
					connection.send_request(@authority, *args)
				end
			end
			
			protected
			
			def connect(connection_limit: nil)
				Pool.new(connection_limit) do
					Async.logger.debug(self) {"Making connection to #{@endpoint.inspect}"}
					
					@endpoint.each do |endpoint|
						peer = endpoint.connect
						
						stream = IO::Stream.new(peer)
						
						break @protocol.client(stream)
					end
				end
			end
		end
	end
end
