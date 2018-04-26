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

require_relative '../body/chunked'
require_relative '../body/fixed'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP11 < Async::IO::Protocol::Line
				CRLF = "\r\n".freeze
				
				def initialize(stream)
					super(stream, CRLF)
					
					@persistent = true
					@count = 0
				end
				
				attr :count
				
				# Only one simultaneous connection at a time.
				def multiplex
					1
				end
				
				def reusable?
					@persistent
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
				
				def persistent?(headers)
					headers['connection'] != CLOSE
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while true
						request = Request.new(*read_request)
						@count += 1
						
						response = yield request
						
						response.version ||= request.version
						
						write_response(response.version, response.status, response.headers, response.body)
						
						request.finish
						
						unless persistent?(request.headers) and persistent?(response.headers)
							@persistent = false
							
							break
						end
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				def call(request)
					@count += 1
					
					request.version ||= self.version
					
					Async.logger.debug(self) {"#{request.method} #{request.path} #{request.headers.inspect}"}
					write_request(request.authority, request.method, request.path, request.version, request.headers, request.body)
					
					return Response.new(*read_response)
				rescue EOFError
					Async.logger.debug(self) {"Connection failed with EOFError after #{@count} requests."}
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
					
					@keep_alive = persistent?(headers)
					
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
					if body.nil? or body.empty?
						@stream.write("Content-Length: 0\r\n\r\n")
						body.read if body
					elsif chunked
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
						body = Body::Buffered.for(body)
						
						@stream.write("Content-Length: #{body.bytesize}\r\n\r\n")
						
						body.each do |chunk|
							@stream.write(chunk)
						end
					end
				end
				
				def read_body(headers)
					if headers['transfer-encoding'] == 'chunked'
						return Body::Chunked.new(self)
					elsif content_length = headers['content-length']
						return Body::Fixed.new(@stream, Integer(content_length))
					end
				end
			end
		end
	end
end
