# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2022, by Marco Concetto Rudilosso.
# Copyright, 2023, by Thomas Morgan.

require "protocol/http2/stream"

require_relative "input"
require_relative "output"

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Stream < ::Protocol::HTTP2::Stream
					def initialize(*)
						super
						
						@headers = nil
						
						@pool = nil
						
						# Input buffer, reading request body, or response body (receive_data):
						@length = nil
						@input = nil
						
						# Output buffer, writing request body or response body (window_updated):
						@output = nil
					end
					
					attr_accessor :headers
					
					attr_accessor :pool
					
					attr :input
					
					def add_header(key, value)
						if key == CONNECTION
							raise ::Protocol::HTTP2::HeaderError, "Connection header is not allowed!"
						elsif key.start_with? ":"
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
						if @headers and frame.end_stream?
							self.receive_trailing_headers(super, frame.end_stream?)
						else
							self.receive_initial_headers(super, frame.end_stream?)
						end
						
						if @input and frame.end_stream?
							@input.close_write
						end
					rescue ::Protocol::HTTP2::HeaderError => error
						Console.debug(self, "Error while processing headers!", error)
						
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
								@input.close_write
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
						return if self.closed?
						
						trailer = @output&.trailer
						
						@output = nil
						
						if error
							send_reset_stream(::Protocol::HTTP2::Error::INTERNAL_ERROR)
						else
							# Write trailer?
							if trailer&.any?
								send_headers(trailer, ::Protocol::HTTP2::END_STREAM)
							else
								send_data(nil, ::Protocol::HTTP2::END_STREAM)
							end
						end
					end
					
					def window_updated(size)
						super
						
						@output&.window_updated(size)
						
						return true
					end
					
					# When the stream transitions to the closed state, this method is called. There are roughly two ways this can happen:
					# - A frame is received which causes this stream to enter the closed state. This method will be invoked from the background reader task.
					# - A frame is sent which causes this stream to enter the closed state. This method will be invoked from that task.
					# While the input stream is relatively straight forward, the output stream can trigger the second case above
					def closed(error)
						super
						
						if input = @input
							@input = nil
							input.close_write(error)
						end
						
						if output = @output
							@output = nil
							output.stop(error)
						end
						
						if pool = @pool and @connection
							pool.release(@connection)
						end
						
						return self
					end
				end
			end
		end
	end
end
