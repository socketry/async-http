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
	
	context '#read_request' do
		let(:stream) {Async::IO::Stream.new(io)}
		subject {described_class.new(stream)}

		describe "simple request" do
			let(:request) {"GET / HTTP/1.1\r\nHost: localhost\r\nAccept: */*\r\n\r\n"}
			let(:io) {StringIO.new(request)}
		
			it "reads request" do
				authority, method, url, version, headers, body = subject.read_request
				
				expect(authority).to be == 'localhost'
				expect(method).to be == 'GET'
				expect(url).to be == '/'
				expect(version).to be == 'HTTP/1.1'
				expect(headers).to be == {'accept' => ['*/*']}
				expect(body).to be nil
			end
		end
		
		describe "simple request with fixed body" do
			let(:request) {"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 11\r\n\r\nHello World"}
			let(:io) {StringIO.new(request)}
		
			it "reads request" do
				authority, method, url, version, headers, body = subject.read_request
				
				expect(authority).to be == 'localhost'
				expect(method).to be == 'GET'
				expect(url).to be == '/'
				expect(version).to be == 'HTTP/1.1'
				expect(headers).to be == {'content-length' => "11"}
				expect(body.read).to be == "Hello World"
			end
		end
		
		describe "simple request with chunked body" do
			let(:request) {"GET / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nHello World\r\n0\r\n\r\n"}
			let(:io) {StringIO.new(request)}
			
			it "reads request" do
				authority, method, url, version, headers, body = subject.read_request
				
				expect(authority).to be == 'localhost'
				expect(method).to be == 'GET'
				expect(url).to be == '/'
				expect(version).to be == 'HTTP/1.1'
				expect(headers).to be == {'transfer-encoding' => ['chunked']}
				expect(body.read).to be == "Hello World"
			end
		end
	end
	
	context 'invalid content length' do
		include_context Async::HTTP::Server
		
		it "should fail with negative content length" do
			expect do
				client.post("/", {'content-length' => '-1'})
			end.to raise_error(EOFError)
		end
	end
	
	context 'raw response hijack' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
				peer.write_lines(
					"#{request.version} 200 It worked!",
					"connection: close",
					"",
					"Hello World!"
				)
				peer.close
				
				nil
			end
		end
		
		it "reads raw response" do
			response = client.get("/")
			expect(response.read).to be == "Hello World!\r\n"
		end
	end
end
