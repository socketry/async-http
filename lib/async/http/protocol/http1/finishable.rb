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
					# Initialize the finishable wrapper.
					# @parameter body [Protocol::HTTP::Body::Readable] The body to wrap.
					def initialize(body)
						super(body)
						
						@closed = Async::Variable.new
						@error = nil
						
						@reading = false
					end
					
					# @returns [Boolean] Whether the body has started reading.
					def reading?
						@reading
					end
					
					# Read the next chunk from the body.
					# @returns [String | Nil] The next chunk of data.
					def read
						@reading = true
						
						super
					end
					
					# Close the body and signal any waiting tasks.
					def close(error = nil)
						super
						
						unless @closed.resolved?
							@error = error
							@closed.value = true
						end
					end
					
					# Wait for the body to be fully consumed or discard it.
					# @parameter persistent [Boolean] Whether the connection will be reused.
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
					
					# @returns [String] A detailed representation of this finishable body.
					def inspect
						"#<#{self.class} closed=#{@closed} error=#{@error}> | #{super}"
					end
				end
			end
		end
	end
end
