# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2020, by Bruno Sutic.

require 'protocol/http/body/wrapper'

module Async
	module HTTP
		module Body
			class Delayed < ::Protocol::HTTP::Body::Wrapper
				def initialize(body, delay = 0.01)
					super(body)
					
					@delay = delay
				end
				
				def ready?
					false
				end
				
				def read
					Async::Task.current.sleep(@delay)
					
					return super
				end
			end
		end
	end
end
