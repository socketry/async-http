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
require 'async/io/stream'

require_relative 'protocol'
require_relative 'body/streamable'
require_relative 'middleware'

module Async
	module HTTP
		class Client
			def initialize(endpoint, protocol = endpoint.protocol, scheme = endpoint.scheme, authority = endpoint.authority, retries: 3, connection_limit: nil)
				@endpoint = endpoint
				@protocol = protocol
				
				@retries = retries
				@pool = make_pool(connection_limit)
				
				@scheme = scheme
				@authority = authority
			end
			
			attr :endpoint
			attr :protocol
			
			attr :retries
			attr :pool
			
			attr :scheme
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
				@pool.close
			end
			
			include Methods
			
			def call(request)
				request.scheme ||= self.scheme
				request.authority ||= self.authority
				
				attempt = 0
				
				# We may retry the request if it is possible to do so. https://tools.ietf.org/html/draft-nottingham-httpbis-retry-01 is a good guide for how retrying requests should work.
				begin
					attempt += 1
					
					# As we cache pool, it's possible these pool go bad (e.g. closed by remote host). In this case, we need to try again. It's up to the caller to impose a timeout on this. If this is the last attempt, we force a new connection.
					connection = @pool.acquire
					
					response = connection.call(request)
					
					# The connection won't be released until the body is completely read/released.
					Body::Streamable.wrap(response) do
						@pool.release(connection)
					end
					
					return response
				rescue Protocol::RequestFailed
					# This is a specific case where the entire request wasn't sent before a failure occurred. So, we can even resend non-idempotent requests.
					@pool.release(connection) if connection
					
					attempt += 1
					if attempt < @retries
						retry
					else
						raise
					end
				rescue
					@pool.release(connection) if connection
					
					if request.idempotent? and attempt < @retries
						retry
					else
						raise
					end
				end
			end
			
			protected
			
			def make_pool(connection_limit = nil)
				Pool.new(connection_limit) do
					Async.logger.debug(self) {"Making connection to #{@endpoint.inspect}"}
					
					peer = @endpoint.connect
					peer.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
					
					@protocol.client(IO::Stream.new(peer))
				end
			end
		end
	end
end
