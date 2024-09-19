# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "protocol/http/body/wrapper"
require "async/variable"

module Async
	module HTTP
		module Body
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
					unless @closed.resolved?
						@error = error
						@closed.value = true
					end
					
					super
				end
				
				def wait
					if @reading
						@closed.wait
					else
						self.discard
					end
				end
				
				def inspect
					"#<#{self.class} closed=#{@closed} error=#{@error}> | #{super}"
				end
			end
		end
	end
end
