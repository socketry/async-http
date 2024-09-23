# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "protocol/http/body/wrapper"
require "async/variable"

module Async
	module HTTP
		module Protocol
			module HTTP1
				# Keeps track of whether a body is being read, and if so, waits for it to be closed.
				class Finishable < ::Protocol::HTTP::Body::Wrapper
					def initialize(body)
						super(body)
						
						@closed = Async::Variable.new
						@error = nil
						
						@reading = false
					end
					
					def reading?
						@reading
					end
					
					def read
						@reading = true
						
						super
					end
					
					def close(error = nil)
						super
						
						unless @closed.resolved?
							@error = error
							@closed.value = true
						end
					end
					
					def wait(persistent = true)
						if @reading
							@closed.wait
						elsif persistent
							# If the connection can be reused, let's gracefully discard the body:
							self.discard
						else
							# Else, we don't care about the body, so we can close it immediately:
							self.close
						end
					end
					
					def inspect
						"#<#{self.class} closed=#{@closed} error=#{@error}> | #{super}"
					end
				end
			end
		end
	end
end
