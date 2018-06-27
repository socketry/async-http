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

require_relative 'body/buffered'
require_relative 'body/reader'
require_relative 'middleware'

module Async
	module HTTP
		class Request
			prepend Body::Reader
			
			def initialize(authority = nil, method = nil, path = nil, version = nil, headers = [], body = nil)
				@authority = authority
				@method = method
				@path = path
				@version = version
				@headers = headers
				@body = body
			end
			
			attr_accessor :authority
			attr_accessor :method
			attr_accessor :path
			attr_accessor :version
			attr_accessor :headers
			attr_accessor :body
			
			def head?
				self.method == HEAD
			end
			
			def connect?
				self.method == CONNECT
			end
			
			def self.[](method, path, headers, body)
				body = Body::Buffered.wrap(body)
				
				self.new(nil, method, path, nil, headers, body)
			end
			
			def idempotent?
				method != POST && (body.nil? || body.empty?)
			end
			
			def to_s
				"#{@method} #{@path} #{@version}"
			end
		end
	end
end
