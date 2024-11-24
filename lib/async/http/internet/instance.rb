# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.

require_relative "../internet"

::Thread.attr_accessor :async_http_internet_instance

module Async
	module HTTP
		class Internet
			# The global instance of the internet.
			def self.instance
				::Thread.current.async_http_internet_instance ||= self.new
			end
			
			class << self
				::Protocol::HTTP::Methods.each do |name, verb|
					define_method(verb.downcase) do |url, *arguments, **options, &block|
						self.instance.call(verb, url, *arguments, **options, &block)
					end
				end
			end
		end
	end
end
