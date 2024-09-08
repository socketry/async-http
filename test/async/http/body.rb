# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require 'async/http/body'

require 'sus/fixtures/async'
require 'sus/fixtures/openssl'
require 'sus/fixtures/async/http'
require 'localhost/authority'
require 'io/endpoint/ssl_endpoint'

ABody = Sus::Shared("a body") do
	with 'echo server' do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				input = request.body
				output = Async::HTTP::Body::Writable.new
				
				Async::Task.current.async do |task|
					input.each do |chunk|
						output.write(chunk.reverse)
					end
					
					output.close_write
				end
				
				Protocol::HTTP::Response[200, [], output]
			end	
		end
		
		it "can stream requests" do
			output = Async::HTTP::Body::Writable.new
			
			reactor.async do |task|
				output.write("Hello World!")
				output.close_write
			end
			
			response = client.post("/", {}, output)
			
			expect(response).to be(:success?)
			expect(response.read).to be == "!dlroW olleH"
		end
	end
	
	with "streaming server" do
		let(:notification) {Async::Notification.new}
		
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				body = Async::HTTP::Body::Writable.new
				
				Async::Task.current.async do |task|
					10.times do |i|
						body.write("#{i}")
						notification.wait
					end
					
					body.close_write
				end
				
				Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		it "can stream response" do
			response = client.get("/")
			
			expect(response).to be(:success?)
			
			j = 0
			# This validates interleaving
			response.body.each do |line|
				expect(line.to_i).to be == j
				j += 1
				
				notification.signal
			end
		end	
	end
end

describe Async::HTTP::Protocol::HTTP1 do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	it_behaves_like ABody
end

describe Async::HTTP::Protocol::HTTPS do
	include Sus::Fixtures::Async::HTTP::ServerContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	let(:authority) {Localhost::Authority.new}
	
	let(:server_context) {authority.server_context}
	let(:client_context) {authority.client_context}
	
	def make_server_endpoint(bound_endpoint)
		::IO::Endpoint::SSLEndpoint.new(super, ssl_context: server_context)
	end
	
	def make_client_endpoint(bound_endpoint)
		::IO::Endpoint::SSLEndpoint.new(super, ssl_context: client_context)
	end
	
	it_behaves_like ABody
end
