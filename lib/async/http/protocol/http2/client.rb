# frozen_string_literal: true
#
# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'connection'
require_relative 'response'

require 'protocol/http2/client'

module Async
	module HTTP
		module Protocol
			module HTTP2
				class Client < ::Protocol::HTTP2::Client
					include Connection
					
					def initialize(stream)
						@stream = stream
						
						framer = ::Protocol::HTTP2::Framer.new(@stream)
						
						super(framer)
					end
					
					def create_response
						Response::Stream.create(self, self.next_stream_id).response
					end
					
					# Used by the client to send requests to the remote server.
					def call(request)
						raise ::Protocol::HTTP2::Error, "Connection closed!" if self.closed?
						
						@count += 1
						
						response = create_response
						response.send_request(request)
						response.wait
						
						return response
					end
				end
			end
		end
	end
end
