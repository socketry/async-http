# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2019-2020, by Brian Morearty.

require_relative 'middleware/location_redirector'

warn "`Async::HTTP::RelativeLocation` is deprecated and will be removed in the next release. Please use `Async::HTTP::Middleware::LocationRedirector` instead.", uplevel: 1

module Async
	module HTTP
		module Middleware
			RelativeLocation = Middleware::LocationRedirector
			TooManyRedirects = RelativeLocation::TooManyRedirects
		end
	end
end
