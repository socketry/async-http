# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "protocol/http/body/buffered"
require_relative "body/writable"

module Async
	module HTTP
		module Body
			include ::Protocol::HTTP::Body
		end
	end
end
