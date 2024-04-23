# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2020, by Sam Shadwell.

require 'async'
require 'async/http/proxy'
require 'async/http/protocol'
require 'async/http/body/hijack'

require 'sus/fixtures/async/http'

AProxy = Sus::Shared("a proxy") do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:protocol) {subject}
	
	with '.proxied_endpoint' do
		it "can construct valid endpoint" do
			endpoint = Async::HTTP::Endpoint.parse("http://www.codeotaku.com")
			proxied_endpoint = client.proxied_endpoint(endpoint)
			
			expect(proxied_endpoint).to be_a(Async::HTTP::Endpoint)
		end
	end
	
	with '.proxied_client' do
		it "can construct valid client" do
			endpoint = Async::HTTP::Endpoint.parse("http://www.codeotaku.com")
			proxied_client = client.proxied_client(endpoint)
			
			expect(proxied_client).to be_a(Async::HTTP::Client)
		end
	end
	
	with 'CONNECT' do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					chunk = stream.read
					stream.close_read
					
					stream.write(chunk)
					stream.close
				end
			end
		end
		
		let(:data) {"Hello World!"}
		
		it "can connect and hijack connection" do
			input = Async::HTTP::Body::Writable.new
			
			response = client.connect("127.0.0.1:1234", [], input)
			
			expect(response).to be(:success?)
			
			input.write(data)
			input.close
			
			expect(response.read).to be == data
		end
	end
	
	with 'echo server' do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				expect(request.path).to be == "localhost:1"
				
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					while chunk = stream.read_partial(1024)
						stream.write(chunk)
						stream.flush
					end
					
					stream.close
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
	
	with 'proxied client' do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				expect(request.method).to be == "CONNECT"
				
				unless authorization_lambda.call(request)
					next Protocol::HTTP::Response[407, [], nil]
				end
				
				host, port = request.path.split(":", 2)
				endpoint = Async::IO::Endpoint.tcp(host, port)
				
				Console.logger.debug(self) {"Making connection to #{endpoint}..."}
				
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					upstream = ::IO::Stream::Buffered.wrap(endpoint.connect)
					Console.logger.debug(self) {"Connected to #{upstream}..."}
					
					reader = Async do |task|
						task.annotate "Upstream reader."
						
						while chunk = upstream.read_partial
							stream.write(chunk)
							stream.flush
						end
					ensure
						Console.logger.debug(self) {"Finished reading from upstream..."}
						stream.close_write
					end
					
					writer = Async do |task|
						task.annotate "Upstream writer."
						
						while chunk = stream.read_partial
							upstream.write(chunk)
							upstream.flush
						end
					rescue Async::Wrapper::Cancelled
						#ignore
					ensure
						Console.logger.debug(self) {"Finished writing to upstream..."}
						upstream.close_write
					end
					
					reader.wait
					writer.wait
				ensure
					upstream.close
					stream.close
				end
			end
		end
		
		let(:authorization_lambda) { ->(request) {true} }
		
		it 'can get insecure website' do
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
		
		it 'can get secure website' do
			endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
			proxy_client = client.proxied_client(endpoint)
			
			response = proxy_client.get("/search")
			
			expect(response).not.to be(:failure?)
			expect(response.read).not.to be(:empty?)
			
			proxy_client.close
		end
		
		with 'authorization header required' do
			let(:authorization_lambda) do
				->(request) {request.headers['proxy-authorization'] == 'supersecretpassword' }
			end
			
			with 'request includes headers' do
				let(:headers) { [['proxy-authorization', 'supersecretpassword']] }
				
				it 'succeeds' do
					endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
					proxy_client = client.proxied_client(endpoint, headers)
					
					response = proxy_client.get('/search')
					
					expect(response).not.to be(:failure?)
					expect(response.read).not.to be(:empty?)
					
					proxy_client.close
				end
			end
			
			with 'request does not include headers' do
				it 'does not succeed' do
					endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
					proxy_client = client.proxied_client(endpoint)
					
					expect do
						# Why is this response not 407? Because the response should come from the proxied connection, but that connection failed to be established. Because of that, there is no response. If we respond here with 407, it would be indistinguisable from the remote server returning 407. That would be an odd case, but none-the-less a valid one.
						response = proxy_client.get('/search')
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
