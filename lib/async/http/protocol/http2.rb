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

require_relative '../request'
require_relative '../response'
require_relative '../body/writable'

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
				VERSION = 'HTTP/2.0'.freeze
				
				def initialize(controller, stream)
					@controller = controller
					@stream = stream
					
					@controller.on(:frame) do |data|
						@stream.write(data)
						@stream.flush
					end
					
					@controller.on(:frame_sent) do |frame|
						Async.logger.debug(self) {"Sent frame: #{frame.inspect}"}
					end
					
					@controller.on(:frame_received) do |frame|
						Async.logger.debug(self) {"Received frame: #{frame.inspect}"}
					end
					
					@count = 0
				end
				
				attr :count
				
				# Multiple requests can be processed at the same time.
				def multiplex
					@controller.remote_settings[:settings_max_concurrent_streams]
				end
				
				def reusable?
					@reader.alive?
				end
				
				def version
					VERSION
				end
				
				def start_connection
					@reader ||= read_in_background
				end
				
				def read_in_background(task: Task.current)
					task.async do |nested_task|
						nested_task.annotate("#{version} reading data")
						
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
				
				def receive_requests(task: Task.current, &block)
					# emits new streams opened by the client
					@controller.on(:stream) do |stream|
						@count += 1
						
						request = Request.new
						request.version = self.version
						request.headers = {}
						body = Body::Writable.new
						request.body = body
						
						stream.on(:headers) do |headers|
							# puts "Got request headers: #{headers.inspect}"
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
						
						stream.on(:data) do |chunk|
							# puts "Got request data: #{chunk.inspect}"
							body.write(chunk.to_s) unless chunk.empty?
						end
						
						stream.on(:half_close) do
							# puts "Generating response..."
							response = yield request
							
							# puts "Finishing body..."
							body.finish
							
							# puts "Sending response..."
							# send response
							headers = {STATUS => response.status.to_s}
							headers.update(response.headers)
							
							# puts "Sending headers #{headers}"
							if response.body.nil? or response.body.empty?
								stream.headers(headers, end_stream: true)
								response.body.read if request.body
							else
								stream.headers(headers, end_stream: false)
								
								# puts "Streaming body..."
								response.body.each do |chunk|
									# puts "Sending chunk #{chunk.inspect}"
									stream.data(chunk, end_stream: false)
								end
								
								# puts "Ending stream..."
								stream.data("", end_stream: true)
							end
						end
					end
					
					start_connection
					@reader.wait
				end
				
				def call(request)
					@count += 1
					
					request.version ||= self.version
					
					stream = @controller.new_stream
					
					headers = {
						SCHEME => HTTPS,
						METHOD => request.method.to_s,
						PATH => request.path.to_s,
						AUTHORITY => request.authority.to_s,
					}.merge(request.headers)
					
					finished = Async::Notification.new
					
					response = Response.new
					response.version = self.version
					response.headers = {}
					body = Body::Writable.new
					response.body = body
					
					stream.on(:headers) do |headers|
						headers.each do |key, value|
							if key == STATUS
								response.status = value.to_i
							elsif key == REASON
								response.reason = value
							else
								response.headers[key] = value
							end
						end
						
						finished.signal
					end
					
					stream.on(:data) do |chunk|
						body.write(chunk.to_s) unless chunk.empty?
					end
					
					stream.on(:close) do
						body.finish
					end
					
					if request.body.nil? or request.body.empty?
						stream.headers(headers, end_stream: true)
						response.body.read if request.body
					else
						stream.headers(headers, end_stream: false)
						
						request.body.each do |chunk|
							stream.data(chunk, end_stream: false)
						end
							
						stream.data("", end_stream: true)
					end
					
					start_connection
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
