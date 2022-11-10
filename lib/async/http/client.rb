# frozen_string_literal: true
#
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

require 'async/pool/controller'

require 'protocol/http/body/completable'
require 'protocol/http/methods'

require 'traces/provider'

require_relative 'protocol'

module Async
	module HTTP
		DEFAULT_RETRIES = 3
		DEFAULT_CONNECTION_LIMIT = nil
		
		class Client < ::Protocol::HTTP::Methods
			# Provides a robust interface to a server.
			# * If there are no connections, it will create one.
			# * If there are already connections, it will reuse it.
			# * If a request fails, it will retry it up to N times if it was idempotent.
			# The client object will never become unusable. It internally manages persistent connections (or non-persistent connections if that's required).
			# @param endpoint [Endpoint] the endpoint to connnect to.
			# @param protocol [Protocol::HTTP1 | Protocol::HTTP2 | Protocol::HTTPS] the protocol to use.
			# @param scheme [String] The default scheme to set to requests.
			# @param authority [String] The default authority to set to requests.
			def initialize(endpoint, protocol: endpoint.protocol, scheme: endpoint.scheme, authority: endpoint.authority, retries: DEFAULT_RETRIES, connection_limit: DEFAULT_CONNECTION_LIMIT)
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
			
			def secure?
				@endpoint.secure?
			end
			
			def self.open(*arguments, **options, &block)
				client = self.new(*arguments, **options)
				
				return client unless block_given?
				
				begin
					yield client
				ensure
					client.close
				end
			end
			
			def close
				while @pool.busy?
					Console.logger.warn(self) {"Waiting for #{@protocol} pool to drain: #{@pool}"}
					@pool.wait
				end
				
				@pool.close
			end
			
			def call(request)
				request.scheme ||= self.scheme
				request.authority ||= self.authority
				
				attempt = 0
				
				# We may retry the request if it is possible to do so. https://tools.ietf.org/html/draft-nottingham-httpbis-retry-01 is a good guide for how retrying requests should work.
				begin
					attempt += 1
					
					# As we cache pool, it's possible these pool go bad (e.g. closed by remote host). In this case, we need to try again. It's up to the caller to impose a timeout on this. If this is the last attempt, we force a new connection.
					connection = @pool.acquire
					
					response = make_response(request, connection)
					
					# This signals that the ensure block below should not try to release the connection, because it's bound into the response which will be returned:
					connection = nil
					
					return response
				rescue Protocol::RequestFailed
					# This is a specific case where the entire request wasn't sent before a failure occurred. So, we can even resend non-idempotent requests.
					if connection
						@pool.release(connection)
						connection = nil
					end
					
					if attempt < @retries
						retry
					else
						raise
					end
				rescue SocketError, IOError, EOFError, Errno::ECONNRESET, Errno::EPIPE
					if connection
						@pool.release(connection)
						connection = nil
					end
					
					if request.idempotent? and attempt < @retries
						retry
					else
						raise
					end
				ensure
					@pool.release(connection) if connection
				end
			end
			
			def inspect
				"#<#{self.class} authority=#{@authority.inspect}>"
			end

			Traces::Provider(self) do
				def call(request)
					attributes = {
						'http.method': request.method,
						'http.authority': request.authority || self.authority,
						'http.scheme': request.scheme || self.scheme,
						'http.path': request.path,
					}
					
					if protocol = request.protocol
						attributes['http.protocol'] = protocol
					end
					
					if length = request.body&.length
						attributes['http.request.length'] = length
					end
					
					trace('async.http.client.call', attributes: attributes) do |span|
						if context = self.trace_context
							request.headers['traceparent'] = context.to_s
							# request.headers['tracestate'] = context.state
						end
						
						super.tap do |response|
							if status = response&.status
								span['http.status_code'] = status
							end
							
							if length = response.body&.length
								span['http.response.length'] = length
							end
						end
					end
				end
			end
			
			protected
			
			def make_response(request, connection)
				response = request.call(connection)
				
				# The connection won't be released until the body is completely read/released.
				::Protocol::HTTP::Body::Completable.wrap(response) do
					@pool.release(connection)
				end
				
				return response
			end
			
			def make_pool(connection_limit)
				Async::Pool::Controller.wrap(limit: connection_limit) do
					Console.logger.debug(self) {"Making connection to #{@endpoint.inspect}"}
					
					@protocol.client(@endpoint.connect)
				end
			end
		end
	end
end
