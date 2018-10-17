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
require 'tempfile'

RSpec.shared_examples_for Async::HTTP::Protocol do
	include_context Async::HTTP::Server
	
	context 'working server' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				if request.method == 'POST'
					# We stream the request body directly to the response.
					Async::HTTP::Response[200, {}, request.body]
				else
					Async::HTTP::Response[200, {
						'remote-address' => request.remote_address.inspect
					}, ["#{request.method} #{request.version}"]]
				end
			end
		end
		
		context 'GET' do
			let(:response) {client.get("/")}
			let(:expected) {"GET #{protocol::VERSION}"}
			
			it "is successful" do
				expect(response).to be_success
				expect(response.read).to eq expected
			end
			
			let(:tempfile) {Tempfile.new}
			
			it "can save to disk" do
				response.save(tempfile.path)
				expect(tempfile.read).to eq expected
				
				tempfile.close
			end
			
			it "has remote-address header" do
				expect(response.headers['remote-address']).to_not be_nil
			end
			
			it "has protocol version" do
				expect(response.version).to_not be_nil
			end
		end
		
		context 'POST' do
			let(:response) {client.post("/", {}, ["Hello", " ", "World"])}
			
			it "is successful" do
				expect(response).to be_success
				expect(response.read).to be == "Hello World"
			end
			
			it "fails gracefully when closing connection" do
				client.pool.acquire do |connection|
					connection.stream.close
				end
			end
		end
	end
	
	context 'hijack with nil response' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				nil
			end
		end
		
		it "fails with appropriate error" do
			response = client.get("/")
			
			expect(response).to be_server_failure
		end
	end
	
	context 'body with incorrect length' do
		let(:bad_body) {Async::HTTP::Body::Buffered.new(["Borked"], 10)}
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				Async::HTTP::Response[200, {}, bad_body]
			end
		end
		
		it "fails with appropriate error" do
			response = client.get("/")
			
			expect do
				response.read
			end.to raise_error(EOFError)
		end
	end
	
	context 'streaming server' do
		let!(:sent_chunks) {[]}
		
		let(:server) do
			chunks = sent_chunks
			
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				body = Async::HTTP::Body::Writable.new
				
				Async::Reactor.run do |task|
					10.times do |i|
						chunk = "Chunk #{i}"
						chunks << chunk
						
						body.write chunk
						task.sleep 0.25
					end
					
					body.finish
				end
				
				Async::HTTP::Response[200, {}, body]
			end
		end
		
		it "can cancel response" do
			response = client.get("/")
			
			expect(response.body.read).to be == "Chunk 0"
			
			response.close
			
			expect(sent_chunks).to be == ["Chunk 0"]
		end
	end
	
	context 'hijack server' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				if request.hijack?
					io = request.hijack
					io.write "HTTP/1.1 200 Okay\r\nContent-Length: 16\r\n\r\nHijack Succeeded"
					io.flush
					io.close
				else
					Async::HTTP::Response[200, {}, ["Hijack Failed"]]
				end
			end
		end
		
		it "will hijack response if possible" do
			response = client.get("/")
			
			expect(response.read).to include("Hijack")
		end
	end
	
	context 'broken server' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				raise RuntimeError.new('simulated failure')
			end
		end
		
		it "can't get /" do
			expect do
				response = client.get("/")
			end.to raise_error(EOFError)
		end
	end
end
