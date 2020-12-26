# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'server_context'

require 'async/http/client'
require 'async/http/endpoint'

RSpec.describe 'consistent retry behaviour' do
	include_context Async::HTTP::Server
	
	let(:delay) {0.1}
	let(:retries) {2}
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:server) do
		Async::HTTP::Server.for(endpoint, protocol: protocol) do |request|
			Async::Task.current.sleep(delay)
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	def make_request(body)
		# This causes the first request to fail with "SocketError" which is retried:
		Async::Task.current.with_timeout(delay / 2, SocketError) do
			return client.get('/', {}, body)
		end
	end
	
	specify 'with nil body' do
		make_request(nil)
	end
	
	specify 'with empty array body' do
		make_request([])
	end
end
