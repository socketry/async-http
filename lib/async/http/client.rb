# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2022, by Ian Ker-Seymer.

require "io/endpoint"

require "async/pool/controller"

require "protocol/http/body/completable"
require "protocol/http/methods"

require_relative "protocol"

module Async
	module HTTP
		DEFAULT_RETRIES = 3
		
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
			def initialize(endpoint, protocol: endpoint.protocol, scheme: endpoint.scheme, authority: endpoint.authority, retries: DEFAULT_RETRIES, **options)
				@endpoint = endpoint
				@protocol = protocol
				
				@retries = retries
				@pool = make_pool(**options)
				
				@scheme = scheme
				@authority = authority
			end
			
			def as_json(...)
				{
					endpoint: @endpoint.to_s,
					protocol: @protocol,
					retries: @retries,
					scheme: @scheme,
					authority: @authority,
				}
			end
			
			def to_json(...)
				as_json.to_json(...)
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
				@pool.wait_until_free do
					Console.warn(self) {"Waiting for #{@protocol} pool to drain: #{@pool}"}
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
					
					response = make_response(request, connection, attempt)
					
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
					if connection
						@pool.release(connection)
					end
				end
			end
			
			def inspect
				"#<#{self.class} authority=#{@authority.inspect}>"
			end
			
			protected
			
			def make_response(request, connection, attempt)
				response = request.call(connection)
				
				response.pool = @pool
				
				return response
			end
			
			def assign_default_tags(tags)
				tags[:endpoint] = @endpoint.to_s
				tags[:protocol] = @protocol.to_s
			end
			
			def make_pool(**options)
				if connection_limit = options.delete(:connection_limit)
					warn "The connection_limit: option is deprecated, please use limit: instead.", uplevel: 2
					options[:limit] = connection_limit
				end
				
				self.assign_default_tags(options[:tags] ||= {})
				
				Async::Pool::Controller.wrap(**options) do
					Console.debug(self) {"Making connection to #{@endpoint.inspect}"}
					
					@protocol.client(@endpoint.connect)
				end
			end
		end
	end
end
