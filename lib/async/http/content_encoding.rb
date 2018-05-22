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
require_relative 'body/deflate'

module Async
	module HTTP
		# Encode a response according the the request's acceptable encodings.
		class ContentEncoding < Middleware
			DEFAULT_WRAPPERS = {
				'gzip' => Body::Deflate.method(:for)
			}
			
			DEFAULT_CONTENT_TYPES = %r{^(text/.*?)|(.*?/json)|(.*?/javascript)$}
			
			def initialize(app, content_types = DEFAULT_CONTENT_TYPES, wrappers = DEFAULT_WRAPPERS)
				super(app)
				
				@content_types = content_types
				@wrappers = wrappers
			end
			
			def call(request, *)
				response = super
				
				# TODO use http-accept and sort by priority
				if !response.body.empty? and accept_encoding = request.headers['accept-encoding']
					if content_type = response.headers['content-type'] and @content_types =~ content_type
						body = response.body
						
						accept_encoding.each do |name|
							if wrapper = @wrappers[name]
								response.headers['content-encoding'] = name
								
								body = wrapper.call(body)
								
								break
							end
						end
						
						response.body = body
					end
				end
				
				return response
			end
		end
	end
end
