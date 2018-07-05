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

RSpec.describe Async::HTTP::Client, timeout: 5 do
	describe Async::HTTP::Protocol::HTTP1 do
		include_context Async::HTTP::Server
		
		it "client can get resource" do
			response = client.get("/")
			response.read
			expect(response).to be_success
		end
	end
	
	context 'non-existant host' do
		include_context Async::RSpec::Reactor
		
		let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://the.future')}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should fail to connect" do
			expect do
				client.get("/")
			end.to raise_error(SocketError, /not known/)
		end
	end
	
	describe Async::HTTP::Protocol::HTTPS do
		include_context Async::RSpec::Reactor
		
		let(:endpoint) {Async::HTTP::URLEndpoint.parse('https://www.codeotaku.com')}
		let(:client) {Async::HTTP::Client.new(endpoint)}
		
		it "should specify hostname" do
			expect(endpoint.hostname).to be == "www.codeotaku.com"
			expect(client.authority).to be == "www.codeotaku.com"
		end
		
		it "can request remote resource" do
			response = client.get("/index")
			expect(response).to be_success
			
			response = client.get("/index")
			expect(response).to be_success
			
			response.finish
			client.close
		end
		
		it "can request remote resource with compression" do
			compressor = Async::HTTP::AcceptEncoding.new(client)
			
			response = compressor.get("/index", {'accept-encoding' => 'gzip'})
			expect(response).to be_success
			
			expect(response.headers['content-encoding']).to be == ['gzip']
			expect(response.read).to be_start_with('<!DOCTYPE html>')
			
			response.finish
			client.close
		end
	end
end
