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
require 'async/http/body/hijack'
require 'tempfile'

RSpec.shared_examples_for Async::HTTP::Protocol do
	include_context Async::HTTP::Server
	
	it "should have valid scheme" do
		expect(client.scheme).to be == "http"
	end
	
	context 'buffered body' do
		let(:body) {Async::HTTP::Body::Buffered.new(["Hello World"])}
		let(:response) {Async::HTTP::Response[200, {}, body]}
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				response
			end
		end
		
		it "response should be closed" do
			expect(body).to receive(:close).and_call_original
			# expect(response).to receive(:close).and_call_original
			
			expect(client.get("/", {}).read).to be == "Hello World"
		end
	end
	
	context 'working server' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				if request.method == 'POST'
					# We stream the request body directly to the response.
					Async::HTTP::Response[200, {}, request.body]
				elsif request.method == 'GET'
					expect(request.body).to be nil
					
					Async::HTTP::Response[200, {
						'remote-address' => request.remote_address.inspect
					}, ["#{request.method} #{request.version}"]]
				end
			end
		end
		
		it "should have valid scheme" do
			expect(server.scheme).to be == "http"
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
				
				expect(client.pool).to_not be_busy
			end
			
			it "can buffer response" do
				buffer = response.finish
				
				expect(buffer.join).to be == "Hello World"
				
				expect(client.pool).to_not be_busy
			end
			
			it "should not contain content-length response header" do
				expect(response.headers).to_not include('content-length')
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
	
	context 'partial hijack' do
		let(:content) {"Hello World!"}
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					stream.write content
					stream.close
				end
			end
		end
		
		it "reads hijacked body" do
			response = client.get("/")
			
			expect(response.read).to be == content
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
					io = request.hijack!
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
	
	context 'slow server' do
		let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9294', reuse_port: true, timeout: 0.1)}
		
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				Async::Task.current.sleep(endpoint.timeout * 2)
				Async::HTTP::Response[200, {}, []]
			end
		end
		
		it "can't get /" do
			expect do
				client.get("/")
			end.to raise_error(Async::TimeoutError)
		end
	end
	
	context 'bi-directional streaming' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				# Echo the request body back to the client.
				Async::HTTP::Response[200, {}, request.body]
			end
		end
		
		it "can read from request body and write response body simultaneously" do
			body = Async::HTTP::Body::Writable.new
			
			# Ideally, the flow here is as follows:
			# 1/ Client writes headers to server.
			# 2/ Client starts writing data to server (in async task).
			# 3/ Client reads headers from server.
			# 4a/ Client reads data from server.
			# 4b/ Client finishes sending data to server.
			response = client.post(endpoint.path, [], body)
			
			expect(response).to be_success
			
			body.write "."
			count = 1
			
			response.each do |chunk|
				if chunk.bytesize > 32
					body.close
				else
					count += 1
					body.write chunk*2
					Async::Task.current.sleep(0.1)
				end
			end
			
			expect(count).to be == 7
		end
	end
end
