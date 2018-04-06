# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'request'
require_relative 'response'

require 'async/notification'

require 'http/2'

module Async
	module HTTP
		module Protocol
			# A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
			class HTTP2
				def self.client(stream)
					self.new(::HTTP2::Client.new, stream)
				end
				
				def self.server(stream)
					self.new(::HTTP2::Server.new, stream)
				end
				
				HTTPS = 'https'.freeze
				SCHEME = ':scheme'.freeze
				METHOD = ':method'.freeze
				PATH = ':path'.freeze
				AUTHORITY = ':authority'.freeze
				REASON = ':reason'.freeze
				STATUS = ':status'.freeze
				
				def initialize(controller, stream)
					@controller = controller
					@stream = stream
					
					@controller.on(:frame) do |data|
						@stream.write(data)
						@stream.flush
					end
					
					# @controller.on(:frame_sent) do |frame|
					# 	Async.logger.debug(self) {"Sent frame: #{frame.inspect}"}
					# end
					# 
					# @controller.on(:frame_received) do |frame|
					# 	Async.logger.debug(self) {"Received frame: #{frame.inspect}"}
					# end
					
					if @controller.is_a? ::HTTP2::Client
						@controller.send_connection_preface
						@reader = read_in_background
					end
				end
				
				# Multiple requests can be processed at the same time.
				def multiplex
					@controller.remote_settings[:settings_max_concurrent_streams]
				end
				
				def reusable?
					@reader.alive?
				end
				
				def read_in_background(task: Task.current)
					task.async do |nested_task|
						buffer = Async::IO::BinaryString.new
						
						while data = @stream.io.read(1024*8, buffer)
							@controller << data
						end
						
						Async.logger.debug(self) {"Connection reset by peer!"}
					end
				end
				
				def close
					Async.logger.debug(self) {"Closing connection"}
					@reader.stop
					@stream.close
				end
				
				def receive_requests(&block)
					# emits new streams opened by the client
					@controller.on(:stream) do |stream|
						request = Request.new
						request.version = "HTTP/2.0"
						request.headers = {}
						
						# stream.on(:active) { } # fires when stream transitions to open state
						# stream.on(:close) { } # stream is closed by client and server
						
						stream.on(:headers) do |headers|
							headers.each do |key, value|
								if key == METHOD
									request.method = value
								elsif key == PATH
									request.path = value
								elsif key == AUTHORITY
									request.authority = value
								else
									request.headers[key] = value
								end
							end
						end
						
						stream.on(:data) do |body|
							request.body = body
						end
						
						stream.on(:half_close) do
							response = yield request
							
							# send response
							stream.headers(STATUS => response[0].to_s)
							
							stream.headers(response[1]) unless response[1].empty?
							
							response[2].each do |chunk|
								stream.data(chunk, end_stream: false)
							end
							
							stream.data("", end_stream: true)
						end
					end
					
					while data = @stream.io.read(1024)
						@controller << data
					end
				end
				
				RESPONSE_VERSION = 'HTTP/2'.freeze
				
				def send_request(authority, method, path, headers = {}, body = nil)
					stream = @controller.new_stream
					
					internal_headers = {
						SCHEME => HTTPS,
						METHOD => method,
						PATH => path,
						AUTHORITY => authority,
					}.merge(headers)
					
					stream.headers(internal_headers, end_stream: true)
					
					# if body
					# 	body.each do |chunk|
					# 		stream.data(chunk, end_stream: false)
					# 	end
					# 
					# 	stream.data("", end_stream: true)
					# end
					
					response = Response.new
					response.version = RESPONSE_VERSION
					response.headers = {}
					response.body = Async::IO::BinaryString.new
					
					stream.on(:headers) do |headers|
						# Async.logger.debug(self) {"Stream headers: #{headers.inspect}"}
						
						headers.each do |key, value|
							if key == STATUS
								response.status = value.to_i
							elsif key == REASON
								response.reason = value
							else
								response.headers[key] = value
							end
						end
					end
					
					stream.on(:data) do |body|
						# Async.logger.debug(self) {"Stream data: #{body.size} bytes"}
						response.body << body
					end
					
					finished = Async::Notification.new
					
					stream.on(:half_close) do
						# Async.logger.debug(self) {"Stream half-closed."}
					end
					
					stream.on(:close) do
						# Async.logger.debug(self) {"Stream closed, sending signal."}
						finished.signal
					end
					
					@stream.flush
					
					# Async.logger.debug(self) {"Stream flushed, waiting for signal."}
					finished.wait
					
					# Async.logger.debug(self) {"Stream finished: #{response.inspect}"}
					return response
				end
			end
		end
	end
end
