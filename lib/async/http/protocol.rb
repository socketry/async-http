# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

require_relative "protocol/http1"
require_relative "protocol/https"

module Async
	module HTTP
		# A protocol specifies a way in which to communicate with a remote peer.
		module Protocol
			# A protocol must implement the following interface:
			# class Protocol
			# 	def client(stream) -> Connection
			# 	def server(stream) -> Connection
			# end
			
			# A connection must implement the following interface:
			# class Connection
			# 	def concurrency -> can invoke call 1 or more times simultaneously.
			# 	def reusable? -> can be used again/persistent connection.
			
			# 	def viable? -> Boolean
			
			# 	def call(request) -> Response
			# 	def each -> (yield(request) -> Response)
			# end
		end
	end
end
