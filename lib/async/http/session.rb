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

require_relative 'parser'

module Async
	module HTTP
		Request = Struct.new(:method, :url, :version, :headers, :body) do
			def env
				self.headers
			end
		end
		
		class Session
			CRLF = "\r\n".freeze
			
			def initialize(peer)
				@stream = Async::IO::Stream.new(peer, eol: CRLF)
				
				@parser = Parser.new
			end
			
			attr :stream
			
			def read_request
				Request.new(*@parser.read_request(@stream))
			rescue EOFError
				return nil
			end
			
			def write_response(status, headers, body)
				@stream.puts "HTTP/1.1 #{status}"
				
				headers.each do |name, value|
					@stream.write("#{name}: #{value}\r\n")
				end
				
				@stream.write("Transfer-Encoding: chunked\r\n\r\n")
				
				body.each do |chunk|
					next if chunk.size == 0
					
					@stream.write("#{chunk.size.to_s(16).upcase}\r\n")
					@stream.write(chunk)
					@stream.write("\r\n")
				end
				
				@stream.write("0\r\n\r\n")
				
				return true
			rescue Errno::EPIPE
				return false
			end
		end
	end
end
