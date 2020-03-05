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

require_relative 'server_context'

require 'async/http/cache'

require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

require 'async/io/ssl_socket'
require 'async/http/endpoint'
require 'protocol/http/accept_encoding'

RSpec.describe Async::HTTP::Cache, timeout: 5 do
	include_context Async::HTTP::Server
	
	let(:protocol) {Async::HTTP::Protocol::HTTP2}
	
	let(:server) do
		Async::HTTP::Server.for(endpoint, protocol) do |request|
			Protocol::HTTP::Response[200, [['cache-control', 'max-age=1, public']], ['Hello', ' ', 'World']]
		end
	end
	
	subject {described_class.new(client)}
	
	it "should cache GET requests" do
		response = subject.get("/")
		expect(response.read).to be == "Hello World"
		
		10.times do
			response = subject.get("/")
			expect(response.read).to be == "Hello World"
		end
		
		expect(subject).to have_attributes(count: 10)
	end
	
	it "should not cache POST requests" do
		response = subject.post("/")
		expect(response.read).to be == "Hello World"
		
		response = subject.post("/")
		expect(response.read).to be == "Hello World"
		
		expect(subject).to have_attributes(count: 0)
	end
end
