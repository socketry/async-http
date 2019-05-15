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
require 'async/http/endpoint'
require 'async/http/accept_encoding'
require 'async/http/content_encoding'

RSpec.describe Async::HTTP::ContentEncoding, timeout: 5 do
	context 'with complete text/plain response' do
		include_context Async::HTTP::Server
		
		let(:protocol) {Async::HTTP::Protocol::HTTP1}
		
		let(:server) do
			Async::HTTP::Server.new(
				described_class.new(Async::HTTP::Middleware::HelloWorld),
				endpoint, protocol
			)
		end
		
		it "can request resource with compression" do
			compressor = Async::HTTP::AcceptEncoding.new(client)
			
			response = compressor.get("/index", {'accept-encoding' => 'gzip'})
			expect(response).to be_success
			
			expect(response.body).to be_kind_of Async::HTTP::Body::Inflate
			expect(response.read).to be == "Hello World!"
			
			client.close
		end
		
		it "can request resource without compression" do
			response = client.get("/index")
			
			expect(response).to be_success
			expect(response.headers).to_not include('content-encoding')
			
			expect(response.read).to be == "Hello World!"
			
			client.close
		end
	end
	
	context 'with partial response' do
		include_context Async::HTTP::Server
		
		let(:protocol) {Async::HTTP::Protocol::HTTP1}
		
		let(:server) do
			app = ->(request){
				Async::HTTP::Response[206, {'content-type' => 'text/plain'}, ["Hello World!"]]
			}
			
			def app.close
			end
			
			Async::HTTP::Server.new(
				described_class.new(app),
				endpoint, protocol
			)
		end
		
		it "can request resource with compression" do
			response = client.get("/index", {'accept-encoding' => 'gzip'})
			expect(response).to be_success
			
			expect(response.headers).to_not include('content-encoding')
			expect(response.read).to be == "Hello World!"
			
			client.close
		end
	end
	
	context 'with existing content encoding' do
		include_context Async::HTTP::Server
		
		let(:protocol) {Async::HTTP::Protocol::HTTP1}
		
		let(:server) do
			app = ->(request){
				Async::HTTP::Response[200, {'content-type' => 'text/plain', 'content-encoding' => 'identity'}, ["Hello World!"]]
			}
			
			def app.close
			end
			
			Async::HTTP::Server.new(
				described_class.new(app),
				endpoint, protocol
			)
		end
		
		it "does not compress response" do
			response = client.get("/index", {'accept-encoding' => 'gzip'})
			
			expect(response).to be_success
			expect(response.headers).to include('content-encoding')
			expect(response.headers['content-encoding']).to be == ['identity']
			
			expect(response.read).to be == "Hello World!"
			
			client.close
		end
	end
end
