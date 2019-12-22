# frozen_string_literal: true
#
# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'protocol/http1'
require_relative 'protocol/https'

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
