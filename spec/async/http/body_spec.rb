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

require 'async/http/body'

require 'async/http/server'
require 'async/http/client'
require 'async/http/url_endpoint'

require 'async/io/ssl_socket'

require 'async/rspec/reactor'
require 'async/rspec/ssl'

RSpec.shared_examples Async::HTTP::Body do
	let(:client) {Async::HTTP::Client.new(client_endpoint, described_class)}
	
	it "can stream requests" do
		server = Async::HTTP::Server.new(server_endpoint, described_class) do |request, peer, address|
			input = request.body
			output = Async::HTTP::Body::Writable.new
			
			Async::Task.current.async do |task|
				input.each do |chunk|
					output.write(chunk.reverse)
				end
				
				output.finish
			end
			
			Async::HTTP::Response[200, {}, output]
		end
		
		server_task = reactor.async do
			server.run
		end
		
		output = Async::HTTP::Body::Writable.new
		
		reactor.async do |task|
			output.write("Hello World!")
			output.finish
		end
		
		response = client.post("/", {}, output)
		expect(response).to be_success
		
		input = response.body
		reversed = input.read
		
		server_task.stop
		client.close
	end
	
	it "can stream response" do
		notification = Async::Notification.new
		
		server = Async::HTTP::Server.new(server_endpoint, described_class) do |request, peer, address|
			body = Async::HTTP::Body::Writable.new
			
			Async::Task.current.async do |task|
				10.times do |i|
					body.write("#{i}")
					notification.wait
				end
				
				body.finish
			end
			
			Async::HTTP::Response[200, {}, body]
		end
		
		server_task = reactor.async do
			server.run
		end
		
		response = client.get("/")
		
		expect(response).to be_success
		
		j = 0
		# This validates interleaving
		response.body.each do |line|
			expect(line.to_i).to be == j
			j += 1
			
			notification.signal
		end
		
		server_task.stop
		client.close
	end
end

RSpec.describe Async::HTTP::Protocol::HTTP1, timeout: 2 do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9296', reuse_port: true)}
	let(:client_endpoint) {endpoint}
	let(:server_endpoint) {endpoint}
	
	it_should_behave_like Async::HTTP::Body
end

RSpec.describe Async::HTTP::Protocol::HTTPS, timeout: 2 do
	include_context Async::RSpec::Reactor
	include_context Async::RSpec::SSL::ValidCertificate
	
	let(:server_context) do
		OpenSSL::SSL::SSLContext.new.tap do |context|
			context.cert = certificate
			
			context.alpn_select_cb = lambda do |protocols|
				protocols.first
			end
			
			context.key = key
		end
	end

	let(:client_context) do
		OpenSSL::SSL::SSLContext.new.tap do |context|
			context.cert_store = certificate_store
			
			context.alpn_protocols = ['h2']
			
			context.verify_mode = OpenSSL::SSL::VERIFY_PEER
		end
	end
	
	# Shared port for localhost network tests.
	let(:endpoint) {Async::IO::Endpoint.tcp("localhost", 9296, reuse_port: true)}
	let(:server_endpoint) {Async::IO::SecureEndpoint.new(endpoint, ssl_context: server_context)}
	let(:client_endpoint) {Async::HTTP::URLEndpoint.parse("https://localhost:9296", ssl_context: client_context)}
	
	it_should_behave_like Async::HTTP::Body
end