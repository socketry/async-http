# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2020, by Sam Shadwell.

require "async"
require "async/http/proxy"
require "async/http/protocol"
require "async/http/body/hijack"

require "sus/fixtures/async/http"

AProxy = Sus::Shared("a proxy") do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:protocol) {subject}
	
	with ".proxied_endpoint" do
		it "can construct valid endpoint" do
			endpoint = Async::HTTP::Endpoint.parse("http://www.codeotaku.com")
			proxied_endpoint = client.proxied_endpoint(endpoint)
			
			expect(proxied_endpoint).to be_a(Async::HTTP::Endpoint)
		end
	end
	
	with ".proxied_client" do
		it "can construct valid client" do
			endpoint = Async::HTTP::Endpoint.parse("http://www.codeotaku.com")
			proxied_client = client.proxied_client(endpoint)
			
			expect(proxied_client).to be_a(Async::HTTP::Client)
		end
	end
	
	with "CONNECT" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					chunk = stream.read
					stream.close_read
					
					stream.write(chunk)
					stream.close_write
				ensure
					stream.close
				end
			end
		end
		
		let(:data) {"Hello World!"}
		
		it "can connect and hijack connection" do
			input = Async::HTTP::Body::Writable.new
			
			response = client.connect(body: input, authority: "127.0.0.1:1234")
			
			expect(response).to be(:success?)
			
			input.write(data)
			input.close_write
			
			expect(response.read).to be == data
		end
	end
	
	with "echo server" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				expect(request.authority).to be == "localhost:1"
				
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					while chunk = stream.read_partial(1024)
						stream.write(chunk)
						stream.flush
					end
					
					stream.close_write
				end
			end
		end
		
		let(:data) {"Hello World!"}
		
		it "can connect to remote system using block" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			expect(proxy.client.pool).to be(:empty?)
			
			proxy.connect do |peer|
				peer.write(data)
				peer.close_write
				
				expect(peer.read).to be == data
			end
			
			proxy.close
			expect(proxy.client.pool).to be(:empty?)
		end
		
		it "can connect to remote system" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			expect(proxy.client.pool).to be(:empty?)
			
			peer = proxy.connect
			
			peer.write(data)
			peer.close_write
			
			expect(peer.read).to be == data
			
			peer.close
			proxy.close
			
			expect(proxy.client.pool).to be(:empty?)
		end
	end
	
	with "independent tunnel directions" do
		let(:request_closed) {Async::Promise.new}
		let(:write_response) {Async::Promise.new}
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					begin
						while stream.read_partial(1024)
						end
					ensure
						request_closed.resolve(true)
					end
					
					write_response.wait
					stream.write("Hello World!")
					stream.flush
				ensure
					stream.close
				end
			end
		end
		
		it "keeps the response open when the request is closed" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			peer = proxy.connect
			
			expect(proxy.client.pool).to be(:busy?)
			
			peer.close_write
			
			current_task = Async::Task.current
			current_task.with_timeout(1) do
				request_closed.wait
			end
			
			expect(proxy.client.pool).to be(:busy?)
			
			write_response.resolve(true)
			
			expect(peer.read).to be == "Hello World!"
			
			current_task.with_timeout(1) do
				current_task.yield while proxy.client.pool.busy?
			end
			
			expect(proxy.client.pool).not.to be(:busy?)
		ensure
			write_response.resolve(true) unless write_response.resolved?
			peer&.close
			proxy&.close
		end
		
		it "closes the response when the peer is closed" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			peer = proxy.connect
			
			expect(proxy.client.pool).to be(:busy?)
			
			peer.close
			expect(peer).to be(:closed?)
			
			current_task = Async::Task.current
			current_task.with_timeout(1) do
				request_closed.wait
				current_task.yield while proxy.client.pool.busy?
			end
			
			# The remote end never finished the response, but the tunnel was closed anyway:
			expect(write_response).not.to be(:resolved?)
			expect(proxy.client.pool).not.to be(:busy?)
		ensure
			write_response.resolve(true) unless write_response.resolved?
			peer&.close
			proxy&.close
		end
	end
	
	with "rejected CONNECT" do
		let(:reason) {"Egress proxying is denied to host 'localhost'."}
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[403, {"content-type" => "text/plain"}, [reason]]
			end
		end
		
		it "exposes the response body" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			
			expect do
				proxy.connect
			end.to raise_exception(Async::HTTP::Proxy::ConnectFailure, message: be == "Failed to connect: 403")
			
			begin
				proxy.connect
			rescue Async::HTTP::Proxy::ConnectFailure => error
				expect(error.response.status).to be == 403
				expect(error.body).to be == reason
			end
			
			expect(error).to be_a(Async::HTTP::Proxy::ConnectFailure)
			
			current_task = Async::Task.current
			current_task.with_timeout(1) do
				current_task.yield while proxy.client.pool.busy?
			end
		ensure
			proxy&.close
		end
		
		with "large response body" do
			let(:reason) {"x" * (Async::HTTP::Proxy::ConnectFailure::MAXIMUM_BODY_SIZE * 4)}
			
			it "reads a bounded amount of the response body" do
				proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
				
				begin
					proxy.connect
				rescue Async::HTTP::Proxy::ConnectFailure => error
					expect(error.body).to be == reason.byteslice(0, Async::HTTP::Proxy::ConnectFailure::MAXIMUM_BODY_SIZE)
				end
				
				expect(error).to be_a(Async::HTTP::Proxy::ConnectFailure)
				
				current_task = Async::Task.current
				current_task.with_timeout(1) do
					current_task.yield while proxy.client.pool.busy?
				end
			ensure
				proxy&.close
			end
		end
		
		with "response body which never finishes" do
			let(:body) {Async::HTTP::Body::Writable.new}
			
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					body.write(reason)
					
					Protocol::HTTP::Response[403, {"content-type" => "text/plain"}, body]
				end
			end
			
			it "propagates the caller's timeout" do
				proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
				
				expect do
					Async::Task.current.with_timeout(0.1) do
						proxy.connect
					end
				end.to raise_exception(Async::TimeoutError)
				
				current_task = Async::Task.current
				current_task.with_timeout(1) do
					current_task.yield while proxy.client.pool.busy?
				end
			ensure
				body.close
				proxy&.close
			end
		end
	end
	
	with "remote end which closes the tunnel slowly" do
		let(:delay) {1}
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					stream.read_until("\r\n\r\n")
					
					stream.write("HTTP/1.1 200 OK\r\ncontent-length: 12\r\n\r\nHello World!")
					stream.flush
					
					# Wait for the client to close its side of the tunnel:
					while stream.read_partial
					end
					
					sleep(delay)
				ensure
					stream.close
				end
			end
		end
		
		it "closes the tunnel without waiting for the remote end" do
			proxied_endpoint = client.proxied_endpoint(Async::HTTP::Endpoint.parse("http://localhost"))
			proxied_client = Async::HTTP::Client.new(proxied_endpoint)
			
			response = proxied_client.get("/")
			expect(response.read).to be == "Hello World!"
			
			proxied_client.close
			
			start_time = Async::Clock.now
			client.close
			
			expect(Async::Clock.now - start_time).to be < (delay / 4.0)
			expect(client.pool).to be(:empty?)
		end
		
		it "closes the tunnel without waiting for the remote end using a block" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 80)
			
			proxy.connect do |peer|
				peer.write("GET / HTTP/1.1\r\nhost: localhost\r\n\r\n")
				
				buffer = String.new
				buffer << peer.readpartial(1024) until buffer.end_with?("Hello World!")
			end
			
			start_time = Async::Clock.now
			
			# HTTP/1 releases the connection once the tunnel's writer task observes the closed request body:
			current_task = Async::Task.current
			current_task.with_timeout(delay) do
				current_task.yield while client.pool.busy?
			end
			
			proxy.close
			
			expect(Async::Clock.now - start_time).to be < (delay / 4.0)
			expect(client.pool).to be(:empty?)
		end
	end
	
	with "proxied client" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				expect(request.method).to be == "CONNECT"
				
				unless authorization_lambda.call(request)
					next Protocol::HTTP::Response[407, [], nil]
				end
				
				host, port = request.authority.split(":", 2)
				endpoint = IO::Endpoint.tcp(host, port)
				
				Console.debug(self){"Making connection to #{endpoint}..."}
				
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					upstream = ::IO::Stream::Buffered.wrap(endpoint.connect)
					Console.debug(self){"Connected to #{upstream}..."}
					
					reader = Async do |task|
						task.annotate "Upstream reader."
						
						while chunk = upstream.read_partial
							stream.write(chunk)
							stream.flush
						end
					ensure
						Console.debug(self){"Finished reading from upstream..."}
						stream.close_write unless stream.closed?
					end
					
					writer = Async do |task|
						task.annotate "Upstream writer."
						
						while chunk = stream.read_partial
							upstream.write(chunk)
							upstream.flush
						end
					rescue ::Protocol::HTTP2::StreamError => error
						# The client resets the tunnel when it closes it:
						Console.debug(self, "Tunnel reset by client.", error)
					ensure
						Console.debug(self){"Finished writing to upstream..."}
						upstream.close_write unless upstream.closed?
					end
					
					reader.wait
					writer.wait
				ensure
					reader.stop
					reader.wait rescue nil
					
					writer.stop
					writer.wait rescue nil
					
					upstream.close
					stream.close
				end
			end
		end
		
		let(:authorization_lambda) {->(request){true}}
		
		it "can get insecure website" do
			endpoint = Async::HTTP::Endpoint.parse("http://www.google.com")
			proxy_client = client.proxied_client(endpoint)
			
			response = proxy_client.get("/search")
			expect(response).not.to be(:failure?)
			
			# The response would be a redirect:
			expect(response).to be(:redirection?)
			response.finish
			
			# The proxy.connnect response is not being released correctly - after pipe is done:
			expect(proxy_client.pool).not.to be(:empty?)
			proxy_client.close
			expect(proxy_client.pool).to be(:empty?)
		end
		
		it "can get secure website" do
			endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
			proxy_client = client.proxied_client(endpoint)
			
			response = proxy_client.get("/search")
			
			expect(response).not.to be(:failure?)
			expect(response.read).not.to be(:empty?)
			
			proxy_client.close
		end
		
		with "authorization header required" do
			let(:authorization_lambda) do
				->(request){request.headers["proxy-authorization"] == "supersecretpassword"}
			end
			
			with "request includes headers" do
				let(:headers) {[["proxy-authorization", "supersecretpassword"]]}
				
				it "succeeds" do
					endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
					proxy_client = client.proxied_client(endpoint, headers)
					
					response = proxy_client.get("/search")
					
					expect(response).not.to be(:failure?)
					expect(response.read).not.to be(:empty?)
					
					proxy_client.close
				end
			end
			
			with "request does not include headers" do
				it "does not succeed" do
					endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
					proxy_client = client.proxied_client(endpoint)
					
					expect do
						# Why is this response not 407? Because the response should come from the proxied connection, but that connection failed to be established. Because of that, there is no response. If we respond here with 407, it would be indistinguisable from the remote server returning 407. That would be an odd case, but none-the-less a valid one.
						response = proxy_client.get("/search")
					end.to raise_exception(Async::HTTP::Proxy::ConnectFailure)
					
					proxy_client.close
				end
			end
		end
	end
end

describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like AProxy
end

describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like AProxy
end

describe Async::HTTP::Protocol::HTTP2 do
	it_behaves_like AProxy
end
