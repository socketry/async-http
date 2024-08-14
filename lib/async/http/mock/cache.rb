# frozen_string_literal: true
#
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

require_relative '../protocol'

module Async
	module HTTP
		module Mock
			class Cache
				Key = Struct.new(:method, :authority, :path, :headers, :body) do
					def self.for(request)
						self.new(request.method, request.authority, request.path, request.headers, request.body)
					end
				end
				
				def initialize(store = {})
					@internet = Async::HTTP::Internet.new
					@store = store
				end
				
				attr :store
				
				def fetch(request)
					@cache.fetch(Key.for(request)) do |key|
						endpoint = @internet.endpoint_for(request)
						response = @internet.client_for(endpoint).call(request)
						response.body = Body::Buffered.wrap(response.body)
						
						@cache[key] = response
					end
				end
				
				def store(request, response)
					@cache[Key.for(request)] = response
				end
				
				def clear
					@cache.clear
				end
			end
		end
	end
end
