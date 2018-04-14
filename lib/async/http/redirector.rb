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
require_relative 'url_endpoint'

module Async
	module HTTP
		# A client wrapper which transparently handles both relative and absolute redirects to a given maximum number of hops.
		class Redirector
			def initialize(client, maximum_hops = 8)
				@client = client
				@maximum_hops = maximum_hops
				
				@clients = {}
			end
			
			def close
				@client.close
				
				@clients.each_value(&:close)
				@clients.clear
			end
			
			def [] location
				url = URI.parse(location)
				
				if url.absolute?
					lookup(url)
				else
					raise ArgumentError.new("Location must be absolute!")
				end
			end
			
			def connect(endpoint)
				@clients[endpoint] ||= Client.new(endpoint)
			end
			
			def lookup(url)
				endpoint = URLEndpoint.new(url)
				client = connect(endpoint)
				
				return client, url.request_uri
			end
			
			VERBS.each do |verb|
				define_method(verb.downcase) do |reference, *args, &block|
					self.request(verb, reference.to_str, *args, &block)
				end
			end
			
			def request(verb, location, headers = {}, body = [])
				client = @client
				hops = 0
				
				# We need to cache the body as it might be submitted multiple times.
				body = BufferedBody.for(body)
				
				while hops < @maximum_hops
					response = client.request(verb, location, headers, body)
					hops += 1
						
					if response.redirection?
						response.finish
						
						uri = URI.parse(response.headers['location'])
						
						if uri.absolute?
							client, location = lookup(uri)
						else
							# TODO improve the computation of the updated location.
							location = (client.endpoint.url + location + uri).request_uri
						end
						
						unless response.preserve_method?
							verb = 'GET'
						end
					else
						return response
					end
				end
				
				raise ArgumentError, "Redirected #{hops} times, exceeded maximum!"
			end
		end
	end
end
