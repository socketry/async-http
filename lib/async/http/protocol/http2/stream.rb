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

require_relative 'input'
require_relative 'output'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Stream < ::Protocol::HTTP2::Stream
					def initialize(*)
						super
						
						@headers = nil
						
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
					
					def receive_trailing_headers(headers, end_stream)
						headers.each do |key, value|
							add_header(key, value)
						end
					end
					
					def process_headers(frame)
						if @headers.nil?
							@headers = ::Protocol::HTTP::Headers.new
							self.receive_initial_headers(super, frame.end_stream?)
						elsif frame.end_stream?
							self.receive_trailing_headers(super, frame.end_stream?)
						else
							raise ::Protocol::HTTP2::HeaderError, "Unable to process headers!"
						end
						
						# TODO this might need to be in an ensure block:
						if @input and frame.end_stream?
							@input.close($!)
							@input = nil
						end
					rescue ::Protocol::HTTP2::HeaderError => error
						Console.logger.error(self, error)
						
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
					def send_body(body, trailer = nil)
						@output = Output.new(self, body, trailer)
						
						@output.start
					end
					
					# Called when the output terminates normally.
					def finish_output(error = nil)
						trailer = @output&.trailer
						
						@output = nil
						
						if error
							send_reset_stream(::Protocol::HTTP2::Error::INTERNAL_ERROR)
						else
							# Write trailer?
							if trailer&.any?
								send_headers(nil, trailer, ::Protocol::HTTP2::END_STREAM)
							else
								send_data(nil, ::Protocol::HTTP2::END_STREAM)
							end
						end
					end
					
					def window_updated(size)
						super
						
						@output&.window_updated(size)
					end
					
					# When the stream transitions to the closed state, this method is called. There are roughly two ways this can happen:
					# - A frame is received which causes this stream to enter the closed state. This method will be invoked from the background reader task.
					# - A frame is sent which causes this stream to enter the closed state. This method will be invoked from that task.
					# While the input stream is relatively straight forward, the output stream can trigger the second case above
					def closed(error)
						super
						
						if @input
							@input.close(error)
							@input = nil
						end
						
						if @output
							@output.stop(error)
							@output = nil
						end
						
						return self
					end
				end
			end
		end
	end
end
