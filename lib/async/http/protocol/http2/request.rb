# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require_relative "../request"
require_relative "stream"

module Async
	module HTTP
		module Protocol
			module HTTP2
				# Typically used on the server side to represent an incoming request, and write the response.
				class Request < Protocol::Request
					# Represents the HTTP/2 stream associated with an incoming server-side request.
					class Stream < HTTP2::Stream
						# Initialize the request stream.
						def initialize(*)
							super
							
							@enqueued = false
							@request = Request.new(self)
						end
						
						attr :request
						
						# Process the initial headers received from the client and construct the request.
						# @parameter headers [Array] The list of header key-value pairs.
						# @parameter end_stream [Boolean] Whether the stream is complete after these headers.
						def receive_initial_headers(headers, end_stream)
							@headers = ::Protocol::HTTP::Headers.new
							
							headers.each do |key, value|
								if key == SCHEME
									raise ::Protocol::HTTP2::HeaderError, "Request scheme already specified!" if @request.scheme
									
									@request.scheme = value
								elsif key == AUTHORITY
									raise ::Protocol::HTTP2::HeaderError, "Request authority already specified!" if @request.authority
									
									@request.authority = value
								elsif key == METHOD
									raise ::Protocol::HTTP2::HeaderError, "Request method already specified!" if @request.method
									
									@request.method = value
								elsif key == PATH
									raise ::Protocol::HTTP2::HeaderError, "Request path is empty!" if value.empty?
									raise ::Protocol::HTTP2::HeaderError, "Request path already specified!" if @request.path
									
									@request.path = value
								elsif key == PROTOCOL
									raise ::Protocol::HTTP2::HeaderError, "Request protocol already specified!" if @request.protocol
									
									@request.protocol = value
								elsif key == CONTENT_LENGTH
									raise ::Protocol::HTTP2::HeaderError, "Request content length already specified!" if @length
									
									@length = Integer(value)
								elsif key == CONNECTION
									raise ::Protocol::HTTP2::HeaderError, "Connection header is not allowed!"
								elsif key.start_with? ":"
									raise ::Protocol::HTTP2::HeaderError, "Invalid pseudo-header #{key}!"
								elsif key =~ /[A-Z]/
									raise ::Protocol::HTTP2::HeaderError, "Invalid characters in header #{key}!"
								else
									add_header(key, value)
								end
							end
							
							@request.headers = @headers
							
							unless @request.valid?
								raise ::Protocol::HTTP2::HeaderError, "Request is missing required headers!"
							else
								# We only construct the input/body if data is coming.
								unless end_stream
									@request.body = prepare_input(@length)
								end
								
								# We are ready for processing:
								@connection.requests.enqueue(@request)
							end
							
							return headers
						end
						
						# Called when the stream is closed.
						# @parameter error [Exception | Nil] The error that caused the close, if any.
						def closed(error)
							@request = nil
							
							super
						end
					end
					
					# Initialize the request from an HTTP/2 stream.
					# @parameter stream [Stream] The HTTP/2 stream for this request.
					def initialize(stream)
						super(nil, nil, nil, nil, VERSION, nil, nil, nil, self.public_method(:write_interim_response))
						
						@stream = stream
					end
					
					attr :stream
					
					# @returns [Connection] The underlying HTTP/2 connection.
					def connection
						@stream.connection
					end
					
					# @returns [Boolean] Whether the request has the required pseudo-headers.
					def valid?
						@scheme and @method and (@path or @method == ::Protocol::HTTP::Methods::CONNECT)
					end
					
					# @returns [Boolean] Whether connection hijacking is supported (not available for HTTP/2).
					def hijack?
						false
					end
					
					NO_RESPONSE = [
						[STATUS, "500"],
					]
					
					# Send a response back to the client via the HTTP/2 stream.
					# @parameter response [Protocol::HTTP::Response | Nil] The response to send.
					def send_response(response)
						if response.nil?
							return @stream.send_headers(NO_RESPONSE, ::Protocol::HTTP2::END_STREAM)
						end
						
						protocol_headers = [
							[STATUS, response.status],
						]
						
						if length = response.body&.length
							protocol_headers << [CONTENT_LENGTH, length]
						end
						
						headers = ::Protocol::HTTP::Headers::Merged.new(
							protocol_headers,
							response.headers.header
						)
						
						if body = response.body and !self.head?
							# This function informs the headers object that any subsequent headers are going to be trailer. Therefore, it must be called *before* sending the headers, to avoid any race conditions.
							trailer = response.headers.trailer!
							
							@stream.send_headers(headers)
							
							@stream.send_body(body, trailer)
						else
							# Ensure the response body is closed if we are ending the stream:
							response.close
							
							@stream.send_headers(headers, ::Protocol::HTTP2::END_STREAM)
						end
					end
					
					# Write an interim (1xx) response to the client.
					# @parameter status [Integer] The interim HTTP status code.
					# @parameter headers [Hash | Nil] Optional interim response headers.
					def write_interim_response(status, headers = nil)
						interim_response_headers = [
							[STATUS, status]
						]
						
						if headers
							interim_response_headers = ::Protocol::HTTP::Headers::Merged.new(interim_response_headers, headers)
						end
						
						@stream.send_headers(interim_response_headers)
					end
				end
			end
		end
	end
end
