# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require_relative "request"
require_relative "response"

require "protocol/http1"
require "protocol/http/peer"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Connection < ::Protocol::HTTP1::Connection
					def initialize(stream, version, **options)
						super(stream, **options)
						
						# On the client side, we need to send the HTTP version with the initial request. On the server side, there are some scenarios (bad request) where we don't know the request version. In those cases, we use this value, which is either hard coded based on the protocol being used, OR could be negotiated during the connection setup (e.g. ALPN).
						@version = version
					end
					
					def to_s
						"\#<#{self.class} negotiated #{@version}, #{@state}>"
					end
					
					def as_json(...)
						to_s
					end
					
					def to_json(...)
						as_json.to_json(...)
					end
					
					attr :version
					
					def http1?
						true
					end
					
					def http2?
						false
					end
					
					def peer
						@peer ||= ::Protocol::HTTP::Peer.for(@stream.io)
					end
					
					attr :count
					
					def concurrency
						1
					end
					
					# Can we use this connection to make requests?
					def viable?
						self.idle? && @stream&.readable?
					end
					
					def reusable?
						@persistent && @stream && !@stream.closed?
					end
				end
			end
		end
	end
end
