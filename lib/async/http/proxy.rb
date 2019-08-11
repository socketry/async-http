# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'body/pipe'

module Async
	module HTTP
		class Proxy
			def self.tcp(client, host, port, headers = [])
				self.new(client, "#{host}:#{port}", headers)
			end
			
			def initialize(client, address, headers = [])
				@client = client
				@address = address
				@headers = headers
			end
			
			attr :client
			
			def close
				while @client.pool.busy?
					@client.pool.wait
				end
				
				@client.close
			end
			
			def connect(&block)
				input = Body::Writable.new
				
				response = @client.connect(@address.to_s, @headers, input)
				
				pipe = Body::Pipe.new(response.body, input)
				
				return pipe.to_io unless block_given?
				
				begin
					yield pipe.to_io
				ensure
					pipe.close
				end
			end
			
			def endpoint(url, **options)
				Endpoint.parse(url, self, **options)
			end
		end
	end
end
