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

require_relative 'client'
require_relative 'endpoint'
require_relative 'reference'

require 'protocol/http/middleware'
require 'protocol/http/body/rewindable'

module Async
	module HTTP
		class TooManyRedirects < StandardError
		end
		
		# A client wrapper which transparently handles both relative and absolute redirects to a given maximum number of hops.
		#
		# The best reference for these semantics is defined by the [Fetch specification](https://fetch.spec.whatwg.org/#http-redirect-fetch).
		#
		# | Redirect using GET                        | Permanent | Temporary |
		# |:-----------------------------------------:|:---------:|:---------:|
		# | Allowed                                   | 301       | 302       |
		# | Preserve original method                  | 308       | 307       |
		#
		# For the specific details of the redirect handling, see:
		# - <https://datatracker.ietf.org/doc/html/rfc7231#section-6-4-2> 301 Moved Permanently.
		# - <https://datatracker.ietf.org/doc/html/rfc7231#section-6-4-3> 302 Found.
		# - <https://datatracker.ietf.org/doc/html/rfc7538 308 Permanent Redirect.
		# - <https://datatracker.ietf.org/doc/html/rfc7231#section-6-4-7> 307 Temporary Redirect.
		#
		class RelativeLocation < ::Protocol::HTTP::Middleware
			# Header keys which should be deleted when changing a request from a POST to a GET as defined by <https://fetch.spec.whatwg.org/#request-body-header-name>.
			PROHIBITED_GET_HEADERS = [
				'content-encoding',
				'content-language',
				'content-location',
				'content-type',
			]
			
			# maximum_hops is the max number of redirects. Set to 0 to allow 1 request with no redirects.
			def initialize(app, maximum_hops = 3)
				super(app)
				
				@maximum_hops = maximum_hops
			end
			
			# The maximum number of hops which will limit the number of redirects until an error is thrown.
			attr :maximum_hops
			
			def redirect_with_get?(request, response)
				# We only want to switch to GET if the request method is something other than get, e.g. POST.
				if request.method != GET
					# According to the RFC, we should only switch to GET if the response is a 301 or 302:
					return response.status == 301 || response.status == 302
				end
			end
			
			def call(request)
				# We don't want to follow redirects for HEAD requests:
				return super if request.head?
				
				if body = request.body
					# We need to cache the body as it might be submitted multiple times if we get a response status of 307 or 308:
					body = ::Protocol::HTTP::Body::Rewindable.new(body)
					request.body = body
				end
				
				hops = 0
				
				while hops <= @maximum_hops
					response = super(request)
					
					if response.redirection?
						hops += 1
						
						# Get the redirect location:
						unless location = response.headers['location']
							return response
						end
						
						response.finish
						
						uri = URI.parse(location)
						
						if uri.absolute?
							return response
						else
							request.path = Reference[request.path] + location
						end
						
						if request.method == GET or response.preserve_method?
							# We (might) need to rewind the body so that it can be submitted again:
							body&.rewind
						else
							# We are changing the method to GET:
							request.method = GET
							
							# Clear the request body:
							request.finish
							body = nil
							
							# Remove any headers which are not allowed in a GET request:
							PROHIBITED_GET_HEADERS.each do |header|
								request.headers.delete(header)
							end
						end
					else
						return response
					end
				end
				
				raise TooManyRedirects, "Redirected #{hops} times, exceeded maximum!"
			end
		end
	end
end
