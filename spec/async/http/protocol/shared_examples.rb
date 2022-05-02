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

require_relative '../server_context'

require 'async'
require 'async/clock'
require 'async/http/client'
require 'async/http/server'
require 'async/http/endpoint'
require 'async/http/body/hijack'
require 'tempfile'

require 'protocol/http/body/file'

require 'async/rspec/profile'

RSpec.shared_examples_for Async::HTTP::Protocol do
	include_context Async::HTTP::Server
	
	it "should have valid scheme" do
		expect(client.scheme).to be == "http"
	end
	
	context "huge body", timeout: 600 do
		let(:body) {Protocol::HTTP::Body::File.open("/dev/zero", size: 512*1024**2)}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		it "client can download data quickly" do |example|
			response = client.get("/")
			expect(response).to be_success
			
			data_size = 0
			duration = Async::Clock.measure do
				while chunk = response.body.read
					data_size += chunk.bytesize
					chunk.clear
				end
				
				response.finish
			end
			
			size_mbytes = data_size / 1024**2
			
			example.reporter.message "Data size: #{size_mbytes}MB Duration: #{duration.round(2)}s Throughput: #{(size_mbytes / duration).round(2)}MB/s"
		end
	end
	
	context 'buffered body' do
		let(:body) {Async::HTTP::Body::Buffered.new(["Hello World"])}
		let(:response) {Protocol::HTTP::Response[200, {}, body]}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				response
			end
		end
		
		it "response body should be closed" do
			expect(body).to receive(:close).and_call_original
			# expect(response).to receive(:close).and_call_original
			
			expect(client.get("/", {}).read).to be == "Hello World"
		end
	end
	
	context 'empty body' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[204]
			end
		end
		
		it 'properly handles no content responses' do
			expect(client.get("/", {}).read).to be_nil
		end
	end
	
	context 'with trailer', if: described_class.bidirectional? do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				if trailer = request.headers['trailer']
					expect(request.headers).to_not include('etag')
					request.finish
					expect(request.headers).to include('etag')
					
					Protocol::HTTP::Response[200, [], "request trailer"]
				else
					headers = Protocol::HTTP::Headers.new
					headers.add('trailer', 'etag')
					
					body = Async::HTTP::Body::Writable.new
					
					Async do |task|
						body.write("response trailer")
						task.sleep(0.01)
						headers.add('etag', 'abcd')
						body.close
					end
					
					Protocol::HTTP::Response[200, headers, body]
				end
			end
		end
		
		it "can send request trailer" do
			headers = Protocol::HTTP::Headers.new
			headers.add('trailer', 'etag')
			body = Async::HTTP::Body::Writable.new
			
			Async do |task|
				body.write("Hello")
				task.sleep(0.01)
				headers.add('etag', 'abcd')
				body.close
			end
			
			response = client.post("/", headers, body)
			expect(response.read).to be == "request trailer"
			
			expect(response).to be_success
		end
		
		it "can receive response trailer" do
			response = client.get("/")
			expect(response.headers).to include('trailer')
			headers = response.headers
			expect(headers).to_not include('etag')
			
			expect(response.read).to be == "response trailer"
			expect(response).to be_success
			
			# It was sent as a trailer.
			expect(headers).to include('etag')
		end
	end
	
	context 'with working server' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				if request.method == 'POST'
					# We stream the request body directly to the response.
					Protocol::HTTP::Response[200, {}, request.body]
				elsif request.method == 'GET'
					expect(request.body).to be nil
					
					Protocol::HTTP::Response[200, {
						'remote-address' => request.remote_address.inspect
					}, ["#{request.method} #{request.version}"]]
				else
					Protocol::HTTP::Response[200, {}, ["Hello World"]]
				end
			end
		end
		
		it "should have valid scheme" do
			expect(server.scheme).to be == "http"
		end
		
		it "disconnects slow clients" do
			response = client.get("/")
			response.read
			
			# We expect this connection to be closed:
			connection = response.connection
			
			reactor.sleep(1.0)
			
			response = client.get("/")
			response.read
			
			expect(connection).to_not be_reusable
			
			# client.close
			# reactor.sleep(0.1)
			# reactor.print_hierarchy
		end
		
		context 'using GET method' do
			let(:expected) {"GET #{protocol::VERSION}"}
			
			it "can handle many simultaneous requests", timeout: 10 do |example|
				duration = Async::Clock.measure do
					10.times do
						tasks = 100.times.collect do
							Async do
								client.get("/")
							end
						end
						
						tasks.each do |task|
							response = task.wait
							expect(response).to be_success
							expect(response.read).to eq expected
						end
					end
				end
				
				example.reporter.message "Pool: #{client.pool}"
				example.reporter.message "Duration = #{duration.round(2)}"
			end
			
			context 'with response' do
				let(:response) {client.get("/")}
				after {response.finish}
				
				it "can finish gracefully" do
					expect(response).to be_success
				end
				
				it "is successful" do
					expect(response).to be_success
					expect(response.read).to eq expected
				end
				
				it "provides content length" do
					expect(response.body.length).to_not be_nil
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
		end
		
		context 'HEAD' do
			let(:response) {client.head("/")}
			after {response.finish}
			
			it "is successful and without body" do
				expect(response).to be_success
				expect(response.body).to_not be_nil
				expect(response.body).to be_empty
				expect(response.body.length).to_not be_nil
				expect(response.read).to be_nil
			end
		end
		
		context 'POST' do
			let(:response) {client.post("/", {}, ["Hello", " ", "World"])}
			
			after {response.finish}
			
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
	
	context 'content length' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, [], ["Content Length: #{request.body.length}"]]
			end
		end
		
		it "can send push promises" do
			response = client.post("/test", [], ["Hello World!"])
			expect(response).to be_success
			
			expect(response.body.length).to be == 18
			expect(response.read).to be == "Content Length: 12"
		end
	end
	
	context 'hijack with nil response' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
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
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					stream.write content
					stream.write content
					stream.close
				end
			end
		end
		
		it "reads hijacked body" do
			response = client.get("/")
			
			expect(response.read).to be == (content*2)
		end
	end
	
	context 'body with incorrect length' do
		let(:bad_body) {Async::HTTP::Body::Buffered.new(["Borked"], 10)}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, {}, bad_body]
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
			
			Async::HTTP::Server.for(@bound_endpoint) do |request|
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
				
				Protocol::HTTP::Response[200, {}, body]
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
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				if request.hijack?
					io = request.hijack!
					io.write "HTTP/1.1 200 Okay\r\nContent-Length: 16\r\n\r\nHijack Succeeded"
					io.flush
					io.close
				else
					Protocol::HTTP::Response[200, {}, ["Hijack Failed"]]
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
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				raise RuntimeError.new('simulated failure')
			end
		end
		
		it "can't get /" do
			expect do
				response = client.get("/")
			end.to raise_error(Exception)
		end
	end
	
	context 'slow server' do
		let(:endpoint) {Async::HTTP::Endpoint.parse('http://127.0.0.1:9294', reuse_port: true, timeout: 0.1)}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Async::Task.current.sleep(endpoint.timeout * 2)
				Protocol::HTTP::Response[200, {}, []]
			end
		end
		
		it "can't get /" do
			expect do
				client.get("/")
			end.to raise_error(Async::TimeoutError)
		end
	end
	
	context 'bi-directional streaming', if: described_class.bidirectional? do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				# Echo the request body back to the client.
				Protocol::HTTP::Response[200, {}, request.body]
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
			count = 0
			
			response.each do |chunk|
				if chunk.bytesize > 32
					body.close
				else
					count += 1
					body.write chunk*2
					Async::Task.current.sleep(0.1)
				end
			end
			
			expect(count).to be == 6
		end
	end
	
	context 'multiple client requests' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, {}, [request.path]]
			end
		end
		
		around do |example|
			current = Console.logger.level
			Console.logger.fatal!
			
			example.run
		ensure
			Console.logger.level = current
		end
		
		it "doesn't cancel all requests" do
			tasks = []
			task = Async::Task.current
			stopped = []
			
			10.times do
				tasks << task.async {
					begin
						loop do
							client.get('http://127.0.0.1:8080/a').finish
						end
					ensure
						stopped << 'a'
					end
				}
			end
			
			10.times do
				tasks << task.async {
					begin
						loop do
							client.get('http://127.0.0.1:8080/b').finish
						end
					ensure
						stopped << 'b'
					end
				}
			end
			
			tasks.each do |child|
				task.sleep 0.01
				child.stop
			end
			
			expect(stopped.sort).to be == stopped
		end
	end
end
