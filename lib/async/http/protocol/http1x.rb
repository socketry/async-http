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

require_relative 'http10'
require_relative 'http11'

module Async
	module HTTP
		module Protocol
			# A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
			class HTTP1x < Async::IO::Protocol::Line
				HANDLERS = {
					"HTTP/1.0" => HTTP10,
					"HTTP/1.1" => HTTP11,
				}
				
				def initialize(stream, mode, handlers: HANDLERS)
					super(stream, HTTP11::CRLF)
					
					@mode = mode
					@handlers = handlers
				end
				
				def create_handler(version)
					if klass = @handlers[version]
						klass.new(@stream, @mode)
					else
						raise RuntimeError, "Unsupported protocol version #{version}"
					end
				end
				
				def receive_requests(&block)
					method, path, version = self.peek_line.split(/\s+/, 3)
					
					create_handler(version).receive_requests(&block)
				end
				
				def send_request(request, &block)
					create_handler(request.version).send_request(request, &block)
				end
			end
		end
	end
end
