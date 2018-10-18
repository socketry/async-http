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

require_relative 'client'
require_relative 'url_endpoint'
require_relative 'middleware'
require_relative 'body/buffered'

module Async
	module HTTP
		class Internet
			def initialize
				@clients = {}
			end
			
			def call(method, url, headers = [], body = nil)
				endpoint = URLEndpoint.parse(url)
				
				client = @clients.fetch(endpoint) do
					@clients[endpoint] = Client.new(endpoint)
				end
				
				body = Body::Buffered.wrap(body)
				
				request = Request.new(endpoint.authority, method, endpoint.path, nil, headers, body)
				
				return client.call(request)
			end
			
			def close
				@clients.each_value(&:close)
				@clients.clear
			end
			
			VERBS.each do |verb|
				define_method(verb.downcase) do |url, headers = [], body = nil|
					self.call(verb, url.to_str, headers, body)
				end
			end
		end
	end
end
