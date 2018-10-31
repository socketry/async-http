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

require_relative 'middleware'

require_relative 'body/buffered'
require_relative 'body/inflate'

module Async
	module HTTP
		# Set a valid accept-encoding header and decode the response.
		class AcceptEncoding < Middleware
			ACCEPT_ENCODING = 'accept-encoding'.freeze
			CONTENT_ENCODING = 'content-encoding'.freeze
			
			DEFAULT_WRAPPERS = {
				'gzip' => Body::Inflate.method(:for),
				'identity' => ->(body){body},
			}
			
			def initialize(app, wrappers = DEFAULT_WRAPPERS)
				super(app)
				
				@accept_encoding = wrappers.keys.join(', ')
				@wrappers = wrappers
			end
			
			def call(request)
				request.headers[ACCEPT_ENCODING] = @accept_encoding
				
				response = super
				
				if body = response.body and !body.empty? and content_encoding = response.headers.delete(CONTENT_ENCODING)
					# We want to unwrap all encodings
					content_encoding.reverse_each do |name|
						if wrapper = @wrappers[name]
							body = wrapper.call(body)
						end
					end
					
					response.body = body
				end
				
				return response
			end
		end
	end
end
