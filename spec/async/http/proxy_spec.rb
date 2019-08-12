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

require 'async'
require 'async/http/proxy'
require 'async/http/protocol'
require 'async/http/body/hijack'

require_relative 'server_context'

RSpec.shared_examples_for Async::HTTP::Proxy do
	include_context Async::HTTP::Server
	
	context 'CONNECT' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
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
			
			expect(response).to be_success
			
			input.write(data)
			input.close
			
			expect(response.read).to be == data
		end
	end
	
	context 'echo server' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
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
			expect(proxy.client.pool).to be_empty
			
			proxy.connect do |peer|
				stream = Async::IO::Stream.new(peer)
				
				stream.write(data)
				stream.close_write
				
				expect(stream.read).to be == data
			end
			
			proxy.close
			expect(proxy.client.pool).to be_empty
		end
		
		it "can connect to remote system" do
			proxy = Async::HTTP::Proxy.tcp(client, "localhost", 1)
			expect(proxy.client.pool).to be_empty
			
			stream = Async::IO::Stream.new(proxy.connect)
			
			stream.write(data)
			stream.close_write
			
			expect(stream.read).to be == data
			
			stream.close
			proxy.close
			
			expect(proxy.client.pool).to be_empty
		end
	end
	
	context 'proxied client' do
		let(:server) do
			Async::HTTP::Server.for(endpoint, protocol) do |request|
				expect(request.method).to be == "CONNECT"
				
				host, port = request.path.split(":", 2)
				endpoint = Async::IO::Endpoint.tcp(host, port)
				
				Async::HTTP::Body::Hijack.response(request, 200, {}) do |stream|
					upstream = Async::IO::Stream.new(endpoint.connect)
					
					reader = Async do
						while chunk = upstream.read_partial
							stream.write(chunk)
							stream.flush
						end
						
						stream.close_write
					end
					
					writer = Async do
						begin
							while chunk = stream.read_partial
								upstream.write(chunk)
								upstream.flush
							end
							
							upstream.close_write
						rescue Async::Wrapper::Cancelled
							#ignore
						end
					end
					
					begin
						reader.wait
						writer.wait
					
					ensure
						upstream.close
						stream.close
					end
				end
			end
		end
		
		it 'can get insecure website' do
			endpoint = Async::HTTP::Endpoint.parse("http://www.codeotaku.com")
			proxy_client = client.proxy_for(endpoint)
			
			response = proxy_client.get("/index")
			expect(response).to_not be_failure
			
			# If a connection is persistent, it will go back into the pool when the response is closed.
			expect(response.read).to_not be_empty
			expect(response.body).to be_nil
			
			# The proxy.connnect response is not being released correctly - after pipe is done.
			expect(proxy_client.pool).to_not be_empty
			proxy_client.close
			expect(proxy_client.pool).to be_empty
		end
		
		it 'can get secure website' do
			endpoint = Async::HTTP::Endpoint.parse("https://www.codeotaku.com")
			proxy_client = client.proxy_for(endpoint)
			
			response = proxy_client.get("/index")
			
			expect(response).to_not be_failure
			expect(response.read).to_not be_empty
			
			proxy_client.close
		end
	end
end

RSpec.describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like Async::HTTP::Proxy
end

RSpec.describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like Async::HTTP::Proxy
end

RSpec.describe Async::HTTP::Protocol::HTTP2 do
	it_behaves_like Async::HTTP::Proxy
end
