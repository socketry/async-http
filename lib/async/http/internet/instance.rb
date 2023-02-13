# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2023, by Samuel Williams.

require_relative '../internet'
require 'thread/local'

module Async
	module HTTP
		class Internet
			# Provide access to a shared thread-local instance.
			extend ::Thread::Local
		end
	end
end
