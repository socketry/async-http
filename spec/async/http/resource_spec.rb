#!/usr/bin/env ruby

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/http/server'
require 'async/http/url_endpoint'
require 'async/http/resource'

RSpec.describe Async::HTTP::Resource do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9295', reuse_port: true)}
	
	it "client can get resource" do
		server = Async::HTTP::Server.new(endpoint) do |request, peer, address|
			[200, {'content-type' => 'application/json'}, ['{"foo": "bar"}']]
		end
		
		server_task = reactor.async do
			server.run
		end
		
		client = Async::HTTP::Client.new(endpoint)
		resource = Async::HTTP::Resource.new(client)
		
		response = resource.get
		expect(response).to be_success
		expect(response.body).to be_kind_of Async::HTTP::JSONBody
		expect(response.read).to be == {foo: 'bar'}
		
		server_task.stop
		client.close
	end
end