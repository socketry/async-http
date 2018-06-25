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
	include_context Async::HTTP::Server
	
	let(:server) do
		Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
			Async::HTTP::Response[200, {}, ["Hello World"]]
		end
	end
	
	context 'working server' do
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
	
	context 'hijack with nil response' do
		let(:server) do
			Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
				nil
			end
		end
		
		it "fails with appropriate error" do
			expect do
				response = client.get("/")
			end.to raise_error(EOFError)
		end
	end
	
	context 'streaming server' do
		let!(:sent_chunks) {[]}
		
		let(:server) do
			chunks = sent_chunks
			
			Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
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
			
			response.body.stop(true)
			
			expect(sent_chunks).to be == ["Chunk 0"]
		end
	end
	
	context 'hijack server' do
		let(:server) do
			Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
				if request.hijack?
					io = request.hijack
					io.write "HTTP/1.1 200 Okay\r\nContent-Length: 16\r\n\r\nHijack Succeeded"
					io.flush
					io.close
				else
					return Async::HTTP::Response[200, {}, ["Hijack Failed"]]
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
			Async::HTTP::Server.new(endpoint, protocol) do |request, peer, address|
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
