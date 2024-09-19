# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "protocol/http/body/writable"
require "async/queue"

module Async
	module HTTP
		module Body
			Writable = ::Protocol::HTTP::Body::Writable
		end
	end
end
