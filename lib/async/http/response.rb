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

module Async
	module HTTP
		class Response
			prepend Body::Reader
			
			def initialize(version = nil, status = 200, reason = nil, headers = [], body = nil, protocol = nil)
				@version = version
				@status = status
				@reason = reason
				@headers = headers
				@body = body
				@protocol = protocol
			end
			
			attr_accessor :version
			attr_accessor :status
			attr_accessor :reason
			attr_accessor :headers
			attr_accessor :body
			attr_accessor :protocol
			
			def continue?
				status == 100
			end
			
			def success?
				status >= 200 && status < 300
			end
			
			def partial?
				status == 206
			end
			
			def redirection?
				status >= 300 && status < 400
			end
			
			def preserve_method?
				status == 307 || status == 308
			end
			
			def failure?
				status >= 400 && status < 600
			end
			
			def bad_request?
				status == 400
			end
			
			def server_failure?
				status == 500
			end
			
			def self.[](status, headers = [], body = nil)
				body = Body::Buffered.wrap(body)
				
				self.new(nil, status, nil, headers, body)
			end
			
			def self.for_exception(exception)
				Async::HTTP::Response[500, {'content-type' => 'text/plain'}, ["#{exception.class}: #{exception.message}"]]
			end
			
			def to_s
				"#{@status} #{@reason} #{@version}"
			end
		end
	end
end
