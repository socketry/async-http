# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'protocol/http1'

require_relative 'request'
require_relative 'response'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Connection < ::Protocol::HTTP1::Connection
					def initialize(stream, version)
						super(stream)
						
						@ready = true
						@version = version
					end
					
					def to_s
						"\#<#{self.class} negotiated #{@version}, currently #{@ready ? 'ready' : 'in-use'}>"
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
					
					def read_line?
						@stream.read_until(CRLF)
					end
					
					def read_line
						@stream.read_until(CRLF) or raise EOFError, "Could not read line!"
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
						@ready && @stream&.connected?
					end
					
					def reusable?
						@ready && @persistent && @stream && !@stream.closed?
					end
				end
			end
		end
	end
end
