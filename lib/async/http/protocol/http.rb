# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2024, by Samuel Williams.

require_relative 'http1'
require_relative 'http2'

module Async
	module HTTP
		module Protocol
			# HTTP is an http:// server that auto-selects HTTP/1.1 or HTTP/2 by detecting the HTTP/2
			# connection preface.
			module HTTP
				HTTP2_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
				HTTP2_PREFACE_SIZE = HTTP2_PREFACE.bytesize
				
				def self.protocol_for(stream)
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
						HTTP2
					else
						HTTP1
					end
				end
				
				# Only inbound connections can detect HTTP1 vs HTTP2 for http://.
				# Outbound connections default to HTTP1.
				def self.client(peer, **options)
					HTTP1.client(peer, **options)
				end
				
				def self.server(peer, **options)
					stream = ::IO::Stream(peer)
					
					return protocol_for(stream).server(stream, **options)
				end
				
				def self.names
					["h2", "http/1.1", "http/1.0"]
				end
			end
		end
	end
end
