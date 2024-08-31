# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2020, by Igor Sidorov.

require 'async'
require 'async/clock'
require 'async/http/client'
require 'async/http/server'
require 'async/http/endpoint'
require 'async/http/body/hijack'
require 'tempfile'

require 'protocol/http/body/file'

require 'sus/fixtures/async/http'

module Async
	module HTTP
		AProtocol = Sus::Shared("a protocol") do
			include Sus::Fixtures::Async::HTTP::ServerContext
			
			let(:protocol) {subject}
			
			it "should have valid scheme" do
				expect(client.scheme).to be == "http"
			end
			
			with '#close' do
				it 'can close the connection' do
					Async do |task|
						response = client.get("/")
						expect(response).to be(:success?)
						response.finish
						
						client.close
						
						expect(task.children).to be(:empty?)
					end.wait
				end
			end
			
			with "interim response" do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						request.send_interim_response(103, [["link", "</style.css>; rel=preload; as=style"]])
						
						::Protocol::HTTP::Response[200, {}, ["Hello World"]]
					end
				end
				
				it "can read informational response" do
					called = false
					
					callback = proc do |status, headers|
						called = true
						expect(status).to be == 103
						expect(headers).to have_keys(
							"link" => be == ["</style.css>; rel=preload; as=style"]
						)
					end
					
					response = client.get("/", interim_response: callback)
					expect(response).to be(:success?)
					expect(response.read).to be == "Hello World"
					
					expect(called).to be == true
				end
			end
			
			with "huge body" do
				let(:body) {::Protocol::HTTP::Body::File.open("/dev/zero", size: 8*1024**2)}
				
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						::Protocol::HTTP::Response[200, {}, body]
					end
				end
				
				it "client can download data quickly" do
					response = client.get("/")
					expect(response).to be(:success?)
					
					data_size = 0
					duration = Async::Clock.measure do
						while chunk = response.body.read
							data_size += chunk.bytesize
							chunk.clear
						end
						
						response.finish
					end
					
					size_mbytes = data_size / 1024**2
					
					inform "Data size: #{size_mbytes}MB Duration: #{duration.round(2)}s Throughput: #{(size_mbytes / duration).round(2)}MB/s"
				end
			end
			
			with 'buffered body' do
				let(:body) {Async::HTTP::Body::Buffered.new(["Hello World"])}
				let(:response) {::Protocol::HTTP::Response[200, {}, body]}
				
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						response
					end
				end
				
				it "response body should be closed" do
					expect(body).to receive(:close)
					# expect(response).to receive(:close)
					
					expect(client.get("/", {}).read).to be == "Hello World"
				end
			end
			
			with 'empty body' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						::Protocol::HTTP::Response[204]
					end
				end
				
				it 'properly handles no content responses' do
					expect(client.get("/", {}).read).to be_nil
				end
			end
			
			with 'with trailer' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						if trailer = request.headers['trailer']
							expect(request.headers).not.to have_keys('etag')
							request.finish
							expect(request.headers).to have_keys('etag')
							
							::Protocol::HTTP::Response[200, [], "request trailer"]
						else
							headers = ::Protocol::HTTP::Headers.new
							headers.add('trailer', 'etag')
							
							body = Async::HTTP::Body::Writable.new
							
							Async do |task|
								body.write("response trailer")
								sleep(0.01)
								headers.add('etag', 'abcd')
								body.close
							end
							
							::Protocol::HTTP::Response[200, headers, body]
						end
					end
				end
				
				it "can send request trailer" do
					skip "Protocol does not support trailers!" unless subject.bidirectional?
					
					headers = ::Protocol::HTTP::Headers.new
					headers.add('trailer', 'etag')
					body = Async::HTTP::Body::Writable.new
					
					Async do |task|
						body.write("Hello")
						sleep(0.01)
						headers.add('etag', 'abcd')
						body.close
					end
					
					response = client.post("/", headers, body)
					expect(response.read).to be == "request trailer"
					
					expect(response).to be(:success?)
				end
				
				it "can receive response trailer" do
					skip "Protocol does not support trailers!" unless subject.bidirectional?
					
					response = client.get("/")
					expect(response.headers).to have_keys('trailer')
					headers = response.headers
					expect(headers).not.to have_keys('etag')
					
					expect(response.read).to be == "response trailer"
					expect(response).to be(:success?)
					
					# It was sent as a trailer.
					expect(headers).to have_keys('etag')
				end
			end
			
			with 'with working server' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						if request.method == 'POST'
							# We stream the request body directly to the response.
							::Protocol::HTTP::Response[200, {}, request.body]
						elsif request.method == 'GET'
							expect(request.body).to be_nil
							
							::Protocol::HTTP::Response[200, {'my-header' => 'my-value'}, ["#{request.method} #{request.version}"]]
						else
							::Protocol::HTTP::Response[200, {}, ["Hello World"]]
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
					
					expect(connection).not.to be(:reusable?)
					
					# client.close
					# reactor.sleep(0.1)
					# reactor.print_hierarchy
				end
				
				with 'using GET method' do
					let(:expected) {"GET #{protocol::VERSION}"}
					
					it "can handle many simultaneous requests" do
						duration = Async::Clock.measure do
							10.times do
								tasks = 100.times.collect do
									Async do
										client.get("/")
									end
								end
								
								tasks.each do |task|
									response = task.wait
									expect(response).to be(:success?)
									expect(response.read).to be == expected
								end
							end
						end
						
						inform "Pool: #{client.pool}"
						inform "Duration: #{duration.round(2)}"
					end
					
					with 'with response' do
						let(:response) {client.get("/")}
						
						after do
							response.finish
						end
						
						it "can finish gracefully" do
							expect(response).to be(:success?)
						end
						
						it "is successful" do
							expect(response).to be(:success?)
							expect(response.read).to be == expected
						end
						
						it "provides content length" do
							expect(response.body.length).not.to be_nil
						end
						
						let(:tempfile) {Tempfile.new}
						
						it "can save to disk" do
							response.save(tempfile.path)
							expect(tempfile.read).to be == expected
							
							tempfile.close
						end
						
						it "has response header" do
							expect(response.headers['my-header']).to be == ['my-value']
						end
						
						it "has protocol version" do
							expect(response.version).not.to be_nil
						end
					end
				end
				
				with 'HEAD' do
					let(:response) {client.head("/")}
					
					it "is successful and without body" do
						expect(response).to be(:success?)
						expect(response.body).not.to be_nil
						expect(response.body).to be(:empty?)
						expect(response.body.length).not.to be_nil
						expect(response.read).to be_nil
					end
				end
				
				with 'POST' do
					let(:response) {client.post("/", {}, ["Hello", " ", "World"])}
					
					after do
						response.finish
					end
					
					it "is successful" do
						expect(response).to be(:success?)
						expect(response.read).to be == "Hello World"
						expect(client.pool).not.to be(:busy?)
					end
					
					it "can buffer response" do
						buffer = response.finish
						
						expect(buffer.join).to be == "Hello World"
						
						expect(client.pool).not.to be(:busy?)
					end
					
					it "should not contain content-length response header" do
						expect(response.headers).not.to have_keys('content-length')
					end
					
					it "fails gracefully when closing connection" do
						client.pool.acquire do |connection|
							connection.stream.close
						end
					end
				end
			end
			
			with 'content length' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						::Protocol::HTTP::Response[200, [], ["Content Length: #{request.body.length}"]]
					end
				end
				
				it "can send push promises" do
					response = client.post("/test", [], ["Hello World!"])
					expect(response).to be(:success?)
					
					expect(response.body.length).to be == 18
					expect(response.read).to be == "Content Length: 12"
				end
			end
			
			with 'hijack with nil response' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						nil
					end
				end
				
				it "fails with appropriate error" do
					response = client.get("/")
					
					expect(response).to be(:server_failure?)
				end
			end
			
			with 'partial hijack' do
				let(:content) {"Hello World!"}
				
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
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
			
			with 'body with incorrect length' do
				let(:bad_body) {Async::HTTP::Body::Buffered.new(["Borked"], 10)}
				
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						::Protocol::HTTP::Response[200, {}, bad_body]
					end
				end
				
				it "fails with appropriate error" do
					response = client.get("/")
					
					expect do
						response.read
					end.to raise_exception(EOFError)
				end
			end
			
			with 'streaming server' do
				let(:sent_chunks) {[]}
				
				let(:app) do
					chunks = sent_chunks
					
					::Protocol::HTTP::Middleware.for do |request|
						body = Async::HTTP::Body::Writable.new
						
						Async::Reactor.run do |task|
							10.times do |i|
								chunk = "Chunk #{i}"
								chunks << chunk
								
								body.write chunk
								sleep 0.25
							end
							
							body.finish
						end
						
						::Protocol::HTTP::Response[200, {}, body]
					end
				end
				
				it "can cancel response" do
					response = client.get("/")
					
					expect(response.body.read).to be == "Chunk 0"
					
					response.close
					
					expect(sent_chunks).to be == ["Chunk 0"]
				end
			end
			
			with 'hijack server' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						if request.hijack?
							io = request.hijack!
							io.write "HTTP/1.1 200 Okay\r\nContent-Length: 16\r\n\r\nHijack Succeeded"
							io.flush
							io.close
						else
							::Protocol::HTTP::Response[200, {}, ["Hijack Failed"]]
						end
					end
				end
				
				it "will hijack response if possible" do
					response = client.get("/")
					
					expect(response.read).to be =~ /Hijack/
				end
			end
			
			with 'broken server' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						raise RuntimeError.new('simulated failure')
					end
				end
				
				it "can't get /" do
					expect do
						response = client.get("/")
					end.to raise_exception(Exception)
				end
			end
			
			with 'slow server' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						sleep(endpoint.timeout * 2)
						::Protocol::HTTP::Response[200, {}, []]
					end
				end
				
				it "can't get /" do
					expect do
						client.get("/")
					end.to raise_exception(::IO::TimeoutError)
				end
			end
			
			with 'bi-directional streaming' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						# Echo the request body back to the client.
						::Protocol::HTTP::Response[200, {}, request.body]
					end
				end
				
				it "can read from request body and write response body simultaneously" do
					skip "Protocol does not support bidirectional streaming!" unless subject.bidirectional?
					
					body = Async::HTTP::Body::Writable.new
					
					# Ideally, the flow here is as follows:
					# 1/ Client writes headers to server.
					# 2/ Client starts writing data to server (in async task).
					# 3/ Client reads headers from server.
					# 4a/ Client reads data from server.
					# 4b/ Client finishes sending data to server.
					response = client.post(endpoint.path, [], body)
					
					expect(response).to be(:success?)
					
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
			
			with 'multiple client requests' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						::Protocol::HTTP::Response[200, {}, [request.path]]
					end
				end
				
				it "doesn't cancel all requests" do
					task = Async::Task.current
					tasks = []
					stopped = []
					
					10.times do
						task.async do |child|
							tasks << child
							
							loop do
								response = client.get('/a')
								response.finish
							ensure
								response&.close
							end
						ensure
							stopped << 'a'
						end
					end
					
					10.times do
						task.async do |child|
							tasks << child
							
							loop do
								response = client.get('/b')
								response.finish
							ensure
								response&.close
							end
						ensure
							stopped << 'b'
						end
					end
					
					tasks.each do |child|
						sleep 0.01
						child.stop
						child.wait
					end
					
					expect(stopped.sort).to be == stopped
				end
			end
		end
	end
end
