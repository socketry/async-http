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

require_relative 'request_failed'

require_relative '../request'
require_relative '../response'
require_relative '../headers'

require_relative '../body/chunked'
require_relative '../body/fixed'

module Async
	module HTTP
		module Protocol
			# Implements basic HTTP/1.1 request/response.
			class HTTP11 < Async::IO::Protocol::Line
				CRLF = "\r\n".freeze
				CONNECTION = 'connection'.freeze
				HOST = 'host'.freeze
				CLOSE = 'close'.freeze
				
				VERSION = "HTTP/1.1".freeze
				
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
				
				# Can we use this connection to make requests?
				def good?
					@stream.connected?
				end
				
				def reusable?
					@persistent && !@stream.closed?
				end
				
				class << self
					alias server new
					alias client new
				end
				
				def version
					VERSION
				end
				
				def persistent?(headers)
					headers.delete(CONNECTION) != CLOSE
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while @persistent
						request = Request.new(*read_request)
						
						unless persistent?(request.headers)
							@persistent = false
						end
						
						response = yield request
						
						response.version ||= request.version
						
						write_response(response.version, response.status, response.headers, response.body)
						
						request.finish
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				def call(request)
					request.version ||= self.version
					
					Async.logger.debug(self) {"#{request.method} #{request.path} #{request.headers.inspect}"}
					
					# We carefully interpret https://tools.ietf.org/html/rfc7230#section-6.3.1 to implement this correctly.
					begin
						write_request(request.authority, request.method, request.path, request.version, request.headers)
					rescue
						# If we fail to fully write the request and body, we can retry this request.
						raise RequestFailed.new
					end
					
					# Once we start writing the body, we can't recover if the request fails. That's because the body might be generated dynamically, streaming, etc.
					write_body(request.body)
					
					return Response.new(*read_response)
				rescue
					# This will ensure that #reusable? returns false.
					@stream.close
					
					raise
				end
				
				def write_request(authority, method, path, version, headers)
					@stream.write("#{method} #{path} #{version}\r\n")
					@stream.write("Host: #{authority}\r\n")
					write_headers(headers)
					
					@stream.flush
				end
				
				def read_response
					version, status, reason = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					@count += 1
					
					@persistent = persistent?(headers)
					
					return version, Integer(status), reason, headers, body
				end
				
				def read_request
					method, path, version = read_line.split(/\s+/, 3)
					headers = read_headers
					body = read_body(headers)
					
					@count += 1
					
					return headers.delete(HOST), method, path, version, headers, body
				end
				
				def write_response(version, status, headers, body)
					@stream.write("#{version} #{status}\r\n")
					write_headers(headers)
					write_body(body)
					
					@stream.flush
				end
				
				protected
				
				def write_persistent_header
					@stream.write("Connection: close\r\n") unless @persistent
				end
				
				def write_headers(headers)
					headers.each do |name, value|
						@stream.write("#{name}: #{value}\r\n")
					end
					
					write_persistent_header
				end
				
				def read_headers
					fields = []
					
					each_line do |line|
						if line =~ /^([a-zA-Z\-]+):\s*(.+?)\s*$/
							fields << [$1, $2]
						else
							break
						end
					end
					
					return Headers.new(fields)
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
					
					@stream.flush
				end
				
				def read_body(headers)
					if headers.delete('transfer-encoding') == 'chunked'
						return Body::Chunked.new(self)
					elsif content_length = headers.delete('content-length')
						return Body::Fixed.new(@stream, Integer(content_length))
					end
				end
			end
		end
	end
end
