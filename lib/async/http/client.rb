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

require 'async/io/address'

require_relative 'protocol'

module Async
	module HTTP
		class Client
			def initialize(addresses, protocol_class = Protocol::HTTP11)
				@addresses = addresses
				
				@protocol_class = protocol_class
			end
			
			GET = 'GET'.freeze
			
			def get(path, headers = {})
				connect do |protocol|
					protocol.send_request(GET, path, headers)
				end
			end
			
			private
			
			def connect
				Async::IO::Address.each(@addresses) do |address|
					puts "Connecting to #{address} on process #{Process.pid}"
					
					address.connect do |peer|
						# We only yield for first successful connection.
						return yield @protocol_class.new(peer)
					end
				end
			end
		end
	end
end
