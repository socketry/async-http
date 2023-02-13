# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2019, by Brian Morearty.

require_relative 'http10'
require_relative 'http11'

require_relative 'http2'

require 'openssl'

unless OpenSSL::SSL::SSLContext.instance_methods.include? :alpn_protocols=
	warn "OpenSSL implementation doesn't support ALPN."
	
	class OpenSSL::SSL::SSLContext
		def alpn_protocols= names
			return names
		end
	end
	
	class OpenSSL::SSL::SSLSocket
		def alpn_protocol
			return nil
		end
	end
end

module Async
	module HTTP
		module Protocol
			# A server that supports both HTTP1.0 and HTTP1.1 semantics by detecting the version of the request.
			module HTTPS
				HANDLERS = {
					"h2" => HTTP2,
					"http/1.1" => HTTP11,
					"http/1.0" => HTTP10,
					nil => HTTP11,
				}
				
				def self.protocol_for(peer)
					# alpn_protocol is only available if openssl v1.0.2+
					name = peer.alpn_protocol
					
					Console.logger.debug(self) {"Negotiating protocol #{name.inspect}..."}
					
					if protocol = HANDLERS[name]
						return protocol
					else
						raise ArgumentError, "Could not determine protocol for connection (#{name.inspect})."
					end
				end
				
				def self.client(peer)
					protocol_for(peer).client(peer)
				end
				
				def self.server(peer)
					protocol_for(peer).server(peer)
				end
				
				# Supported Application Layer Protocol Negotiation names:
				def self.names
					HANDLERS.keys.compact
				end
			end
		end
	end
end
