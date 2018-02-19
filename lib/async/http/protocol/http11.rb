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

require 'async/io/protocol/line'

require_relative 'request'
require_relative 'response'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP11 < Async::IO::Protocol::Line
				HTTP_CONTENT_LENGTH = 'HTTP_CONTENT_LENGTH'.freeze
				HTTP_TRANSFER_ENCODING = 'HTTP_TRANSFER_ENCODING'.freeze
				
				CRLF = "\r\n".freeze
				
				def initialize(stream, mode)
					super(stream, CRLF)
				end
				
				HTTP_CONNECTION = 'HTTP_CONNECTION'.freeze
				KEEP_ALIVE = 'keep-alive'.freeze
				CLOSE = 'close'.freeze
				
				VERSION = "HTTP/1.1".freeze
				
				def version
					VERSION
				end
				
				def keep_alive?(headers)
					headers[HTTP_CONNECTION] != CLOSE
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while true
						request = Request.new(*read_request)
						
						status, headers, body = yield request
						
						write_response(request.version, status, headers, body)
						
						break unless keep_alive?(request.headers) && keep_alive?(headers)
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				# Client request.
				def send_request(method, path, headers = {}, body = [])
					write_request(method, path, version, headers, body)
					
					return Response.new(*read_response)
				
				rescue EOFError
					return nil
				end
				
				def write_request(method, path, version, headers, body)
					@stream.write("#{method} #{path} #{version}\r\n")
					write_headers(headers)
					write_body(body)
					
					@stream.flush
					
					return true
				end
				
				def read_response
					version, status, reason = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					return version, Integer(status), reason, headers, body
				end
				
				def read_request
					method, path, version = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					return method, path, version, headers, body
				end
				
				def write_response(version, status, headers, body)
					@stream.write("#{version} #{status}\r\n")
					write_headers(headers)
					write_body(body)
					
					@stream.flush
					
					return true
				end
				
				protected
				
				def write_headers(headers)
					headers.each do |name, value|
						@stream.write("#{name}: #{value}\r\n")
					end
				end
				
				def read_headers(headers = {})
					# Parsing headers:
					each_line do |line|
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
						@stream.write("Transfer-Encoding: chunked\r\n\r\n")
						
						body.each do |chunk|
							next if chunk.size == 0
							
							@stream.write("#{chunk.bytesize.to_s(16).upcase}\r\n")
							@stream.write(chunk)
							@stream.write(CRLF)
						end
						
						@stream.write("0\r\n\r\n")
					else
						buffer = String.new
						body.each{|chunk| buffer << chunk}
						
						@stream.write("Content-Length: #{chunk.bytesize}\r\n\r\n")
						@stream.write(chunk)
					end
				end
				
				def read_body(headers)
					if headers[HTTP_TRANSFER_ENCODING] == 'chunked'
						buffer = Async::IO::BinaryString.new
						
						while true
							size = read_line.to_i(16)
							
							if size == 0
								read_line
								break
							end
							
							buffer << @stream.read(size)
							
							read_line # Consume the trailing CRLF
						end
						
						return buffer
					elsif content_length = headers[HTTP_CONTENT_LENGTH]
						return @stream.read(Integer(content_length))
					end
				end
			end
		end
	end
end
