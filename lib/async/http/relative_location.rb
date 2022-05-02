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

module Async
	module HTTP
		class TooManyRedirects < StandardError
		end
		
		# A client wrapper which transparently handles both relative and absolute redirects to a given maximum number of hops.
		class RelativeLocation < ::Protocol::HTTP::Middleware
			DEFAULT_METHOD = GET
			
			# maximum_hops is the max number of redirects. Set to 0 to allow 1 request with no redirects.
			def initialize(app, maximum_hops = 3)
				super(app)
				
				@maximum_hops = maximum_hops
			end
			
			# The maximum number of hops which will limit the number of redirects until an error is thrown.
			attr :maximum_hops
			
			def call(request)
				hops = 0
				
				# We need to cache the body as it might be submitted multiple times.
				request.finish
				
				while hops <= @maximum_hops
					response = super(request)
					
					if response.redirection?
						hops += 1
						response.finish
						
						location = response.headers['location']
						uri = URI.parse(location)
						
						if uri.absolute?
							return response
						else
							request.path = Reference[request.path] + location
						end
						
						unless response.preserve_method?
							request.method = DEFAULT_METHOD
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
