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

require 'async/http/protocol/http11'
require_relative 'shared_examples'

RSpec.describe Async::HTTP::Protocol::HTTP11, timeout: 2 do
	it_behaves_like Async::HTTP::Protocol
	
	context 'head request' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				Async::HTTP::Response[200, {}, ["Hello", "World"]]
			end
		end
		
		it "doesn't reply with body" do
			5.times do
				response = client.head("/")
				
				expect(response).to be_success
				expect(response.version).to be == "HTTP/1.1"
				expect(response.body).to be nil
				response.read
			end
		end
	end
	
	context 'raw response' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				peer = request.hijack
				
				peer.write(
					"#{request.version} 200 It worked!\r\n" +
					"connection: close\r\n" +
					"\r\n" +
					"Hello World!"
				)
				peer.close
				
				nil
			end
		end
		
		it "reads raw response" do
			response = client.get("/")
			
			expect(response.read).to be == "Hello World!"
		end
	end
	
	context 'bad requests' do
		include_context Async::HTTP::Server
		
		it "should fail with negative content length" do
			response = client.post("/", {'content-length' => '-1'})
			
			expect(response).to be_bad_request
		end
		
		it "should fail with both transfer encoding and content length" do
			response = client.post("/", {'transfer-encoding' => 'chunked', 'content-length' => '0'})
			
			expect(response).to be_bad_request
		end
	end
end
