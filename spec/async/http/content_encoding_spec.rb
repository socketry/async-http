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

require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

require 'async/io/ssl_socket'
require 'async/http/url_endpoint'
require 'async/http/accept_encoding'
require 'async/http/content_encoding'

RSpec.describe Async::HTTP::ContentEncoding, timeout: 5 do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9294', reuse_port: true)}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	subject {described_class.new(Async::HTTP::Middleware::HelloWorld)}
	
	let(:server) do
		middleware = subject
		
		Async::HTTP::Server.new(endpoint) do |request, peer, address|
			middleware.call(request)
		end
	end
	
	let!(:server_task) do
		reactor.async do
			server.run
		end
	end
	
	after(:each) do
		server_task.stop
		subject.close
	end
	
	it "can request resource with compression" do
		compressor = Async::HTTP::AcceptEncoding.new(client)
		
		response = compressor.get("/index", {'accept-encoding' => 'gzip'})
		expect(response).to be_success
		
		expect(response.headers['content-encoding']).to be == ['gzip']
		expect(response.read).to be == "Hello World!"
		
		response.finish
		client.close
	end
end
