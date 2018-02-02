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

module Async
	module HTTP
		class URLEndpoint < Endpoint
			def self.parse(string, **options)
				self.new(URI.parse(string), **options)
			end
			
			def port
				specification.port || (specficiation.scheme == 'https' ? 443 : 80)
			end
			
			def hostname
				specification.hostname
			end
			
			def ssl_context
				if context = options[:ssl_context]
					if params = self.params
						context = context.dup
						context.set_params(params)
					end
				else
					context = ::OpenSSL::SSL::SSLContext.new
					
					if params = self.params
						context.set_params(params)
					end
				end
				
				return context
			end
			
			def endpoint
				endpoint = Async::IO::Endpoint.tcp(hostname, port)
				
				if specification.scheme == 'https'
					# Wrap it in SSL:
					endpoint = Async::IO::SecureEndpoint.new(endpoint,
						ssl_context: ssl_context,
						hostname: self.hostname
					)
				end
				
				return endpoint
			end
		end
	end
end