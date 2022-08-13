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

require_relative '../request'

module Async
	module HTTP
		module Protocol
			module HTTP1
				class Request < Protocol::Request
					def self.read(connection)
						if parts = connection.read_request
							self.new(connection, *parts)
						end
					end

					UPGRADE = 'upgrade'
					
					def initialize(connection, authority, method, path, version, headers, body)
						@connection = connection
						
						# HTTP/1 requests with an upgrade header (which can contain zero or more values) are extracted into the protocol field of the request, and we expect a response to select one of those protocols with a status code of 101 Switching Protocols.
						protocol = headers.delete('upgrade')
						
						super(nil, authority, method, path, version, headers, body, protocol)
					end
					
					def connection
						@connection
					end
					
					def hijack?
						true
					end
					
					def hijack!
						@connection.hijack!
					end
				end
			end
		end
	end
end
