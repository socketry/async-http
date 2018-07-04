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

require_relative '../body/chunked'
require_relative '../body/fixed'

module Async
	module HTTP
		module Protocol
			TRANSFER_ENCODING = 'transfer-encoding'.freeze
			CONTENT_LENGTH = 'content-length'.freeze
			CHUNKED = 'chunked'.freeze
			
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
				
				def peer
					@stream.io
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
					if connection = headers[CONNECTION]
						return !connection.include?(CLOSE)
					else
						return true
					end
				end
				
				# @return [Async::Wrapper] the underlying non-blocking IO.
				def hijack
					@persistent = false
					
					@stream.flush
					
					return @stream.io
				end
				
				class Request < Protocol::Request
					def initialize(protocol)
						super(*protocol.read_request)
						
						@protocol = protocol
					end
					
					def hijack?
						true
					end
					
					def hijack
						@protocol.hijack
					end
				end
				
				def next_request
					# The default is true.
					return nil unless @persistent
					
					request = Request.new(self)
					
					unless persistent?(request.headers)
						@persistent = false
					end
					
					return request
				rescue
					# Bad Request
					write_response(self.version, 400, {}, nil)
					
					raise
				end
				
				# Server loop.
				def receive_requests(task: Task.current)
					while request = next_request
						response = yield(request, self)
						
						return if @stream.closed?
						
						if response
							write_response(self.version, response.status, response.headers, response.body)
						else
							# If the request failed to generate a response, it was an internal server error:
							write_response(self.version, 500, {}, nil)
						end
						
						# Gracefully finish reading the request body if it was not already done so.
						request.finish
						
						# This ensures we yield at least once every iteration of the loop and allow other fibers to execute.
						task.yield
					end
				end
				
				class Response < Protocol::Response
					def initialize(protocol, request)
						super(*protocol.read_response(request))
						
						@protocol = protocol
					end
				end
				
				# Used by the client to send requests to the remote server.
				def call(request)
					Async.logger.debug(self) {"#{request.method} #{request.path} #{request.headers.inspect}"}
					
					# We carefully interpret https://tools.ietf.org/html/rfc7230#section-6.3.1 to implement this correctly.
					begin
						write_request(request.authority, request.method, request.path, self.version, request.headers)
					rescue
						# If we fail to fully write the request and body, we can retry this request.
						raise RequestFailed.new
					end
					
					# Once we start writing the body, we can't recover if the request fails. That's because the body might be generated dynamically, streaming, etc.
					write_body(request.body)
					
					return Response.new(self, request)
				rescue
					# This will ensure that #reusable? returns false.
					@stream.close
					
					raise
				end
				
				def write_request(authority, method, path, version, headers)
					@stream.write("#{method} #{path} #{version}\r\n")
					@stream.write("host: #{authority}\r\n")
					write_headers(headers)
					
					@stream.flush
				end
				
				def read_response(request)
					version, status, reason = read_line.split(/\s+/, 3)
					Async.logger.debug(self) {"#{version} #{status} #{reason}"}
					
					headers = read_headers
					
					@persistent = persistent?(headers)
					
					body = read_response_body(request, status, headers)
					
					@count += 1
					
					return version, Integer(status), reason, headers, body
				end
				
				def read_request
					method, path, version = read_line.split(/\s+/, 3)
					headers = read_headers
					
					@persistent = persistent?(headers)
					
					body = read_request_body(headers)
					
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
					@stream.write("connection: close\r\n") unless @persistent
				end
				
				def write_headers(headers)
					headers.each do |name, value|
						@stream.write("#{name}: #{value}\r\n")
					end
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
				
				def write_empty_body(body)
					# Write empty body:
					write_persistent_header
					@stream.write("content-length: 0\r\n\r\n")
					
					body.read if body
					
					@stream.flush
				end
				
				def write_fixed_length_body(body, length)
					write_persistent_header
					@stream.write("content-length: #{length}\r\n\r\n")
					
					body.each do |chunk|
						@stream.write(chunk)
					end
					
					@stream.flush
				end
				
				def write_chunked_body(body)
					write_persistent_header
					@stream.write("transfer-encoding: chunked\r\n\r\n")
					
					body.each do |chunk|
						next if chunk.size == 0
						
						@stream.write("#{chunk.bytesize.to_s(16).upcase}\r\n")
						@stream.write(chunk)
						@stream.write(CRLF)
						@stream.flush
					end
					
					@stream.write("0\r\n\r\n")
					@stream.flush
				end
				
				def write_body_and_close(body)
					# We can't be persistent because we don't know the data length:
					@persistent = false
					write_persistent_header
					
					@stream.write("\r\n")
					
					body.each do |chunk|
						@stream.write(chunk)
						@stream.flush
					end
					
					@stream.io.close_write
				end
				
				def write_body(body, chunked = true)
					if body.nil? or body.empty?
						write_empty_body(body)
					elsif length = body.length
						write_fixed_length_body(body, length)
					elsif chunked
						write_chunked_body(body)
					else
						write_body_and_close(body)
					end
				end
				
				def read_response_body(request, status, headers)
					# RFC 7230 3.3.3
					# 1.  Any response to a HEAD request and any response with a 1xx
					# (Informational), 204 (No Content), or 304 (Not Modified) status
					# code is always terminated by the first empty line after the
					# header fields, regardless of the header fields present in the
					# message, and thus cannot contain a message body.
					if request.head? or status == 204 or status == 304
						return nil
					end
					
					# 2.  Any 2xx (Successful) response to a CONNECT request implies that
					# the connection will become a tunnel immediately after the empty
					# line that concludes the header fields.  A client MUST ignore any
					# Content-Length or Transfer-Encoding header fields received in
					# such a message.
					if request.connect? and status == 200
						return Body::Remainder.new(@stream)
					end
					
					if body = read_body(headers)
						return body
					else
						# 7.  Otherwise, this is a response message without a declared message
						# body length, so the message body length is determined by the
						# number of octets received prior to the server closing the
						# connection.
						return Body::Remainder.new(@stream)
					end
				end
				
				def read_request_body(headers)
					# 6.  If this is a request message and none of the above are true, then
					# the message body length is zero (no message body is present).
					if body = read_body(headers)
						return body
					end
				end
				
				def read_body(headers)
					# 3.  If a Transfer-Encoding header field is present and the chunked
					# transfer coding (Section 4.1) is the final encoding, the message
					# body length is determined by reading and decoding the chunked
					# data until the transfer coding indicates the data is complete.
					if transfer_encoding = headers[TRANSFER_ENCODING]
						# If a message is received with both a Transfer-Encoding and a
						# Content-Length header field, the Transfer-Encoding overrides the
						# Content-Length.  Such a message might indicate an attempt to
						# perform request smuggling (Section 9.5) or response splitting
						# (Section 9.4) and ought to be handled as an error.  A sender MUST
						# remove the received Content-Length field prior to forwarding such
						# a message downstream.
						if headers[CONTENT_LENGTH]
							raise BadRequest, "Message contains both transfer encoding and content length!"
						end
						
						if transfer_encoding.last == CHUNKED
							return Body::Chunked.new(self)
						else
							# If a Transfer-Encoding header field is present in a response and
							# the chunked transfer coding is not the final encoding, the
							# message body length is determined by reading the connection until
							# it is closed by the server.  If a Transfer-Encoding header field
							# is present in a request and the chunked transfer coding is not
							# the final encoding, the message body length cannot be determined
							# reliably; the server MUST respond with the 400 (Bad Request)
							# status code and then close the connection.
							return Body::Remainder.new(@stream)
						end
					end

					# 5.  If a valid Content-Length header field is present without
					# Transfer-Encoding, its decimal value defines the expected message
					# body length in octets.  If the sender closes the connection or
					# the recipient times out before the indicated number of octets are
					# received, the recipient MUST consider the message to be
					# incomplete and close the connection.
					if content_length = headers[CONTENT_LENGTH]
						length = Integer(content_length)
						if length >= 0
							return Body::Fixed.new(@stream, length)
						else
							raise BadRequest, "Invalid content length: #{content_length}"
						end
					end
				end
			end
		end
	end
end
