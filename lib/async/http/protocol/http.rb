# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "defaulton"

require_relative "http1"
require_relative "http2"

module Async
	module HTTP
		module Protocol
			# HTTP is an http:// server that auto-selects HTTP/1.1 or HTTP/2 by detecting the HTTP/2 connection preface.
			class HTTP
				HTTP2_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
				HTTP2_PREFACE_SIZE = HTTP2_PREFACE.bytesize
				
				# Create a new HTTP protocol instance.
				#
				# @parameter http1 [HTTP1] The HTTP/1 protocol instance.
				# @parameter http2 [HTTP2] The HTTP/2 protocol instance.
				def initialize(http1: HTTP1, http2: HTTP2)
					@http1 = http1
					@http2 = http2
				end
				
				# Determine if the inbound connection is HTTP/1 or HTTP/2.
				#
				# @parameter stream [IO::Stream] The stream to detect the protocol for.
				# @returns [Class] The protocol class to use.
				def protocol_for(stream)
					# Detect HTTP/2 connection preface
					# https://www.rfc-editor.org/rfc/rfc9113.html#section-3.4
					preface = stream.peek do |read_buffer|
						if read_buffer.bytesize >= HTTP2_PREFACE_SIZE
							break read_buffer[0, HTTP2_PREFACE_SIZE]
						elsif read_buffer.bytesize > 0
							# If partial read_buffer already doesn't match, no need to wait for more bytes.
							break read_buffer unless HTTP2_PREFACE[read_buffer]
						end
					end
					
					if preface == HTTP2_PREFACE
						@http2
					else
						@http1
					end
				end
				
				# Create a client for an outbound connection. Defaults to HTTP/1 for plaintext connections.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the protocol, keyed by protocol class.
				def client(peer, **options)
					options = options[@http1] || {}
					
					return @http1.client(peer, **options)
				end
				
				# Create a server for an inbound connection. Able to detect HTTP1 and HTTP2.
				#
				# @parameter peer [IO] The peer to communicate with.
				# @parameter options [Hash] Options to pass to the protocol, keyed by protocol class.
				def server(peer, **options)
					stream = IO::Stream(peer)
					protocol = protocol_for(stream)
					options = options[protocol] || {}
					
					return protocol.server(stream, **options)
				end
				
				extend Defaulton
			end
		end
	end
end
