# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "protocol/http1"

require_relative "request"
require_relative "response"

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Connection < ::Protocol::HTTP1::Connection
					def initialize(stream, version)
						super(stream)
						
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
						@stream.io
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
