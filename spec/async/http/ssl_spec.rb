# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
require 'async/http/endpoint'

require 'async/io/ssl_socket'

require 'async/rspec/reactor'
require 'async/rspec/ssl'

RSpec.describe Async::HTTP::Server, timeout: 5 do
	include_context Async::RSpec::Reactor
	include_context Async::RSpec::SSL::ValidCertificate
	
	describe "application layer protocol negotiation" do
		let(:server_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert = certificate
				
				context.alpn_select_cb = lambda do |protocols|
					protocols.last
				end
				
				context.key = key
			end
		end

		let(:client_context) do
			OpenSSL::SSL::SSLContext.new.tap do |context|
				context.cert_store = certificate_store
				
				context.alpn_protocols = ["h2", "http/1.1"]
				
				context.verify_mode = OpenSSL::SSL::VERIFY_PEER
			end
		end
		
		# Shared port for localhost network tests.
		let(:server_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:6779", ssl_context: server_context)}
		let(:client_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:6779", ssl_context: client_context)}
		
		it "client can get a resource via https" do
			server = Async::HTTP::Server.for(server_endpoint, Async::HTTP::Protocol::HTTP1) do |request|
				Protocol::HTTP::Response[200, {}, ['Hello World']]
			end
			
			client = Async::HTTP::Client.new(client_endpoint)
			
			Async::Reactor.run do |task|
				server_task = task.async do
					server.run
				end
				
				response = client.get("/")
				
				expect(response).to be_success
				expect(response.read).to be == "Hello World"
				
				client.close
				server_task.stop
			end
		end
	end
end