# frozen_string_literal: true

# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/http/client'
require 'protocol/http/headers'
require 'protocol/http/middleware'
require 'async/clock'

require 'protocol/http/body/cacheable'

module Async
	module HTTP
		class Cache < ::Protocol::HTTP::Middleware
			CACHE_CONTROL  = 'cache-control'
			SET_COOKIE = 'set-cookie'
			CONTENT_TYPE = 'content-type'
			AUTHORIZATION = 'authorization'
			
			class Response < ::Protocol::HTTP::Response
				def initialize(response, body)
					@generated_at = Async::Clock.now
					
					super(
						response.version,
						response.status,
						response.headers.dup,
						body,
						response.protocol
					)
					
					@max_age = @headers[CACHE_CONTROL]&.max_age
				end
				
				def cachable?
					if length = @body.length and length > 1024*128
						return false
					end
					
					if set_cookie = @headers[SET_COOKIE]
						return false
					end
					
					if cache_control = @headers[CACHE_CONTROL]
						if cache_control.private?
							return false
						end
						
						if cache_control.public?
							return true
						end
					end
				end
				
				attr :generated_at
				
				def age
					Async::Clock.now - @generated_at
				end
				
				def expired?
					self.age > @max_age
				end
				
				def dup
					dup = super
					
					dup.body = @body.dup
					dup.headers = @headers.dup
					
					return dup
				end
			end
			
			def initialize(app, store: nil, maximum_length: 1024*256)
				super(app)
				
				@count = 0
				
				@responses = store || Hash.new
				@maximum_length = maximum_length
			end
			
			attr :count
			
			def key(request)
				[request.authority, request.method, request.path]
			end
			
			def cachable?(request)
				# We don't support caching requests which have a body:
				if request.body
					return false
				end
				
				# We can't cache upgraded requests:
				if request.protocol
					return false
				end
				
				if request.headers[AUTHORIZATION]
					return false
				end
				
				# We only support caching GET and HEAD requests:
				if request.method == 'GET' || request.method == 'HEAD'
					return true
				end
				
				# Otherwise, we can't cache it:
				return false
			end
			
			def wrap(request, key, response)
				if response.status != 200
					return false
				end
				
				if body = response.body
					if length = body.length
						# Don't cache responses bigger than 128Kb:
						return response if length > @maximum_length
					else
						# Don't cache responses without length:
						return response
					end
				end
				
				Body::Cacheable.wrap(response) do |response, body|
					response = Response.new(response, body)
					
					if response.cachable?
						@responses[key] = response
					end
				end
				
				return response
			end
			
			def call(request)
				key = self.key(request)
				cache_control = request.headers[CACHE_CONTROL]
				
				if response = @responses[key] and !cache_control&.no_cache?
					Async.logger.debug(self) {"Cache hit for #{key}..."}
					@count += 1
					
					if response.expired?
						@responses.delete(key)
						Async.logger.debug(self) {"Cache expired for #{key}..."}
					else
						# Create a dup of the response:
						return response.dup
					end
				end
				
				if cachable?(request) and !cache_control&.no_store?
					Async.logger.debug(self) {"Updating cache for #{key}..."}
					return wrap(request, key, super)
				else
					return super
				end
			end
		end
	end
end
