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

require 'async/http/client'
require 'async/http/server'
require 'async/http/url_endpoint'

RSpec.shared_examples_for Async::HTTP::Protocol do
	include_context Async::RSpec::Reactor
	
	let(:protocol) {described_class}
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9294', reuse_port: true)}
	let!(:client) {Async::HTTP::Client.new(endpoint, protocol)}
	
	let(:server) do
		Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
			if request.method == 'POST'
				# We stream the request body directly to the response.
				Async::HTTP::Response[200, {}, request.body]
			else
				Async::HTTP::Response[200, {}, ["#{request.method} #{request.version}"]]
			end
		end
	end
	
	let!(:server_task) do
		server_task = reactor.async do
			server.run
		end
	end
	
	after(:each) do
		server_task.stop
		client.close
	end
	
	it "can get /" do
		response = client.get("/")
		expect(response).to be_success
		expect(response.read).to be == "GET #{protocol::VERSION}"
	end
	
	it "can post body to /" do
		response = client.post("/", {}, ["Hello", " ", "World"])
		expect(response).to be_success
		expect(response.read).to be == "Hello World"
	end
end
