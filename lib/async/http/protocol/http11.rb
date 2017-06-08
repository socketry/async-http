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

require 'async/io/line_stream'

require_relative 'request'
require_relative 'response'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP11 < IO::LineStream
				HTTP_CONTENT_LENGTH = 'HTTP_CONTENT_LENGTH'.freeze
				HTTP_TRANSFER_ENCODING = 'HTTP_TRANSFER_ENCODING'.freeze
				
				def initialize(io, block_size: 1024*4, **options)
					super(io, eol: "\r\n", block_size: block_size, **options)
				end
				
				HTTP_CONNECTION = 'HTTP_CONNECTION'.freeze
				KEEP_ALIVE = 'keep-alive'.freeze
				CLOSE = 'close'.freeze
				
				def keep_alive?(headers)
					headers[HTTP_CONNECTION] != CLOSE
				end
				
				# Server loop.
				def receive_requests
					while request = Request.new(*self.read_request)
						status, headers, body = yield request
						
						write_response(request.version, status, headers, body)
						
						flush
						
						break unless keep_alive?(request.headers) && keep_alive?(headers)
					end
				end
				
				# Client request.
				def send_request(method, path, headers, body = [])
					write_request(method, path, VERSION, headers, body)
					
					flush
					
					return Response.new(*read_response)
				end
				
				def write_headers(headers)
					headers.each do |name, value|
						self.write("#{name}: #{value}\r\n")
					end
				end
				
				def read_headers(headers = {})
					# Parsing headers:
					self.each do |line|
						if line =~ /^([a-zA-Z\-]+):\s*(.+?)\s*$/
							headers["HTTP_#{$1.tr('-', '_').upcase}"] = $2
						else
							break
						end
					end
					
					return headers
				end
				
				def write_body(body, chunked = true)
					if chunked
						self.write("Transfer-Encoding: chunked\r\n\r\n")
						
						body.each do |chunk|
							next if chunk.size == 0
							
							self.write("#{chunk.size.to_s(16).upcase}\r\n")
							self.write(chunk)
							self.write("\r\n")
						end
						
						self.write("0\r\n\r\n")
					else
						buffer = body.join
						self.write("Content-Length: #{buffer.bytesize}\r\n\r\n")
						self.write(buffer)
						self.write("\r\n")
					end
				end
				
				def read_body(headers)
					if headers[HTTP_TRANSFER_ENCODING] == 'chunked'
						buffer = Async::IO::BinaryString.new
						
						while true
							size = self.read_line.to_i(16)
							
							if size == 0
								self.read_line
								break
							end
							
							buffer << self.read(size)
							self.read_line
						end
						
						return buffer
					elsif content_length = headers[HTTP_CONTENT_LENGTH]
						return self.read(Integer(content_length))
					end
				end
				
				def write_request(method, path, version, headers, body)
					self.write("#{method} #{path} #{version}\r\n")
					
					write_headers(headers)
					
					write_body(body)
					
					return true
				end
				
				def read_response
					version, status, reason = self.read_line.split(/\s+/, 3)
					
					headers = read_headers
					
					body = read_body(headers)
					
					return version, Integer(status), reason, headers, body
				end
				
				def read_request
					method, path, version = self.read_line.split(/\s+/, 3)
					
					headers = read_headers
					
					body = read_body(headers)
					
					return method, path, version, headers, body
				end
				
				def write_response(version, status, headers, body)
					self.write "#{version} #{status}\r\n"
					
					write_headers(headers)
					
					write_body(body)
					
					return true
				end
			end
		end
	end
end
