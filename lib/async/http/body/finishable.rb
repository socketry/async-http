# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http/body/wrapper'
require 'async/variable'

module Async
	module HTTP
		module Body
			class Finishable < ::Protocol::HTTP::Body::Wrapper
				def initialize(body)
					super(body)
					
					@closed = Async::Variable.new
					@error = nil
				end
				
				def close(error = nil)
					unless @closed.resolved?
						@error = error
						@closed.value = true
					end
					
					super
				end
				
				def wait
					@closed.wait
				end
				
				def inspect
					"#<#{self.class} closed=#{@closed} error=#{@error}> | #{super}"
				end
			end
		end
	end
end
