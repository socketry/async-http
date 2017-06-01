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

require 'async/io/stream'

require_relative 'protocol'

module Async
	module HTTP
		class Request < Struct.new(:method, :url, :version, :headers, :body)
			HTTP_1_0 = 'HTTP/1.0'.freeze
			HTTP_1_1 = 'HTTP/1.1'.freeze
			
			HTTP_CONNECTION = 'HTTP_CONNECTION'.freeze
			KEEP_ALIVE = 'keep-alive'.freeze
			CLOSE = 'close'.freeze
			
			def env
				self.headers
			end
			
			def keep_alive?
				case self.headers[HTTP_CONNECTION]
				when CLOSE
					return false
				when KEEP_ALIVE
					return true
				else
					# HTTP/1.0 defaults to Connection: close unless otherwise specified.
					# HTTP/1.1 defaults to Connection: keep-alive unless otherwise specified.
					version != HTTP_1_0
				end
			end
		end
		
		class Session
			CRLF = "\r\n".freeze
			
			def initialize(peer)
				@stream = Async::IO::Stream.new(peer, eol: CRLF)
				
				@protocol = Protocol.new(@stream)
			end
			
			attr :stream
			
			def read_request
				Request.new(*@protocol.read_request)
			rescue EOFError
				return nil
			end
			
			def write_response(request, status, headers, body)
				@protocol.write_response(request.version, status, headers, body)
			rescue Errno::EPIPE
				return false
			end
		end
	end
end
