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

require_relative '../request'
require_relative '../response'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP11 < Async::IO::Protocol::Line
				CRLF = "\r\n".freeze
				
				def initialize(stream)
					super(stream, CRLF)
					
					@keep_alive = true
				end
				
				# Only one simultaneous connection at a time.
				def multiplex
					1
				end
				
				def reusable?
					@keep_alive
				end
				
				class << self
					alias server new
					alias client new
				end
				
				KEEP_ALIVE = 'keep-alive'.freeze
				CLOSE = 'close'.freeze
				
				VERSION = "HTTP/1.1".freeze
				
				def version
					VERSION
				end
				
				def keep_alive?(headers)
					headers['connection'] != CLOSE
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while true
						request = Request.new(*read_request)
						
						status, headers, body = yield request
						
						write_response(request.version, status, headers, body)
						
						request.finish
						
						unless keep_alive?(request.headers) and keep_alive?(headers)
							@keep_alive = false
							
							break
						end
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				# Client request.
				def send_request(authority, method, path, headers = {}, body = [])
					Async.logger.debug(self) {"#{method} #{path} #{headers.inspect}"}
					
					write_request(authority, method, path, version, headers, body)
					
					return Response.new(*read_response)
				rescue EOFError
					return nil
				end
				
				def write_request(authority, method, path, version, headers, body)
					@stream.write("#{method} #{path} #{version}\r\n")
					@stream.write("Host: #{authority}\r\n")
					
					write_headers(headers)
					write_body(body)
					
					@stream.flush
					
					return true
				end
				
				def read_response
					version, status, reason = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					@keep_alive = keep_alive?(headers)
					
					return version, Integer(status), reason, headers, body
				end
				
				def read_request
					method, path, version = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					return headers.delete('host'), method, path, version, headers, body
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
							headers[$1.downcase] = $2
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
							@stream.flush
						end
						
						@stream.write("0\r\n\r\n")
					else
						buffer = String.new
						body.each{|chunk| buffer << chunk}
						
						@stream.write("Content-Length: #{buffer.bytesize}\r\n\r\n")
						@stream.write(buffer)
					end
				end
				
				def read_body(headers)
					if headers['transfer-encoding'] == 'chunked'
						return ChunkedBody.new(self)
					elsif content_length = headers['content-length']
						return FixedBody.new(Integer(content_length), @stream)
					end
				end
			end
		end
	end
end
