# frozen_string_literal: true
#
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

require 'protocol/http2/stream'
require_relative '../../body/writable'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Stream < ::Protocol::HTTP2::Stream
					# A writable body which requests window updates when data is read from it.
					class Input < Body::Writable
						def initialize(stream, length)
							super(length)
							
							@stream = stream
						end
						
						def read
							if chunk = super
								# If we read a chunk fron the stream, we want to extend the window if required so more data will be provided.
								@stream.request_window_update
							end
							
							return chunk
						end
					end
					
					class Output
						def self.for(stream, body)
							output = self.new(stream, body)
							
							output.start
							
							return output
						end
						
						def initialize(stream, body)
							@stream = stream
							@body = body
							
							@window_updated = Async::Condition.new
						end
						
						def start(parent: Task.current)
							if @body.respond_to?(:call)
								@task = parent.async(&self.method(:stream))
							else
								@task = parent.async(&self.method(:passthrough))
							end
						end
						
						def stop(error)
							# Ensure that invoking #close doesn't try to close the stream.
							@stream = nil
							
							@task&.stop
						end
						
						def write(chunk)
							until chunk.empty?
								maximum_size = @stream.available_frame_size
								
								while maximum_size <= 0
									@window_updated.wait
									
									maximum_size = @stream.available_frame_size
								end
								
								break unless chunk = send_data(chunk, maximum_size)
							end
						end
						
						def window_updated(size)
							@window_updated.signal
						end
						
						def close(error = nil)
							if @stream
								if error
									@stream.close(error)
								else
									self.close_write
								end
								
								@stream = nil
							end
						end
						
						def close_write
							@stream.send_data(nil, ::Protocol::HTTP2::END_STREAM)
						end
						
						private
						
						def stream(task)
							task.annotate("Streaming #{@body} to #{@stream}.")
							
							input = @stream.wait_for_input
							
							@body.call(Body::Stream.new(input, self))
						rescue Async::Stop
							# Ignore.
						end
						
						# Reads chunks from the given body and writes them to the stream as fast as possible.
						def passthrough(task)
							task.annotate("Writing #{@body} to #{@stream}.")
							
							while chunk = @body&.read
								self.write(chunk)
							end
							
							self.close_write
						rescue Async::Stop
							# Ignore.
						ensure
							@body&.close($!)
							@body = nil
						end
						
						# Send `maximum_size` bytes of data using the specified `stream`. If the buffer has no more chunks, `END_STREAM` will be sent on the final chunk.
						# @param maximum_size [Integer] send up to this many bytes of data.
						# @param stream [Stream] the stream to use for sending data frames.
						# @return [String, nil] any data that could not be written.
						def send_data(chunk, maximum_size)
							if chunk.bytesize <= maximum_size
								@stream.send_data(chunk, maximum_size: maximum_size)
							else
								@stream.send_data(chunk.byteslice(0, maximum_size), maximum_size: maximum_size)
								
								# The window was not big enough to send all the data, so we save it for next time:
								return chunk.byteslice(maximum_size, chunk.bytesize - maximum_size)
							end
							
							return nil
						end
					end
					
					def initialize(*)
						super
						
						@headers = nil
						@trailers = nil
						
						# Input buffer, reading request body, or response body (receive_data):
						@length = nil
						@input = nil
						
						# Output buffer, writing request body or response body (window_updated):
						@output = nil
					end
					
					attr_accessor :headers
					
					attr :input
					
					def add_header(key, value)
						if key == CONNECTION
							raise ::Protocol::HTTP2::HeaderError, "Connection header is not allowed!"
						elsif key.start_with? ':'
							raise ::Protocol::HTTP2::HeaderError, "Invalid pseudo-header #{key}!"
						elsif key =~ /[A-Z]/
							raise ::Protocol::HTTP2::HeaderError, "Invalid upper-case characters in header #{key}!"
						else
							@headers.add(key, value)
						end
					end
					
					def add_trailer(key, value)
						if @trailers.include(key)
							add_header(key, value)
						else
							raise ::Protocol::HTTP2::HeaderError, "Cannot add trailer #{key} as it was not specified in trailers!"
						end
					end
					
					def receive_trailing_headers(headers, end_stream)
						headers.each do |key, value|
							add_trailer(key, value)
						end
					end
					
					def process_headers(frame)
						if @headers.nil?
							@headers = ::Protocol::HTTP::Headers.new
							self.receive_initial_headers(super, frame.end_stream?)
							@trailers = @headers[TRAILERS]
						elsif @trailers and frame.end_stream?
							self.receive_trailing_headers(super, frame.end_stream?)
						else
							raise ::Protocol::HTTP2::HeaderError, "Unable to process headers!"
						end
					rescue ::Protocol::HTTP2::HeaderError => error
						Async.logger.error(self, error)
						
						send_reset_stream(error.code)
					end
					
					def wait_for_input
						return @input
					end
					
					# Prepare the input stream which will be used for incoming data frames.
					# @return [Input] the input body.
					def prepare_input(length)
						if @input.nil?
							@input = Input.new(self, length)
						else
							raise ArgumentError, "Input body already prepared!"
						end
					end
					
					def update_local_window(frame)
						consume_local_window(frame)
						
						# This is done on demand in `Input#read`:
						# request_window_update
					end
					
					def process_data(frame)
						data = frame.unpack
						
						if @input
							unless data.empty?
								@input.write(data)
							end
							
							if frame.end_stream?
								@input.close
								@input = nil
							end
						end
						
						return data
					rescue ::Protocol::HTTP2::ProtocolError
						raise
					rescue # Anything else...
						send_reset_stream(::Protocol::HTTP2::Error::INTERNAL_ERROR)
					end
					
					# Set the body and begin sending it.
					def send_body(body)
						@output = Output.for(self, body)
					end
					
					def window_updated(size)
						super
						
						@output&.window_updated(size)
					end
					
					def close(error = nil)
						super
						
						if @input
							@input.close(error)
							@input = nil
						end
						
						if @output
							@output.stop(error)
							@output = nil
						end
					end
				end
			end
		end
	end
end
