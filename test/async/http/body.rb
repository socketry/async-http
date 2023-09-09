# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/http/body'

require 'async/http/server'
require 'async/http/client'
require 'async/http/endpoint'

require 'async/io/ssl_socket'

require_relative 'server_context'

require 'localhost/authority'

RSpec.shared_examples Async::HTTP::Body do
	let(:client) {Async::HTTP::Client.new(client_endpoint, protocol: described_class)}
	
	context 'with echo server' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint, protocol: described_class) do |request|
				input = request.body
				output = Async::HTTP::Body::Writable.new
				
				Async::Task.current.async do |task|
					input.each do |chunk|
						output.write(chunk.reverse)
					end
					
					output.close
				end
				
				Protocol::HTTP::Response[200, [], output]
			end	
		end
		
		it "can stream requests" do
			output = Async::HTTP::Body::Writable.new
			
			reactor.async do |task|
				output.write("Hello World!")
				output.close
			end
			
			response = client.post("/", {}, output)
			
			expect(response).to be_success
			expect(response.read).to be == "!dlroW olleH"
		end
	end
	
	context "with streaming server" do
		let(:notification) {Async::Notification.new}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint, protocol: described_class) do |request|
				body = Async::HTTP::Body::Writable.new
				
				Async::Task.current.async do |task|
					10.times do |i|
						body.write("#{i}")
						notification.wait
					end
					
					body.close
				end
				
				Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		it "can stream response" do
			response = client.get("/")
			
			expect(response).to be_success
			
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

RSpec.describe Async::HTTP::Protocol::HTTP1 do
	include_context Async::HTTP::Server
	
	it_should_behave_like Async::HTTP::Body
end

RSpec.describe Async::HTTP::Protocol::HTTPS do
	include_context Async::HTTP::Server
	
	let(:authority) {Localhost::Authority.new}
	
	let(:server_context) {authority.server_context}
	let(:client_context) {authority.client_context}
	
	# Shared port for localhost network tests.
	let(:server_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:0", ssl_context: server_context, reuse_port: true)}
	let(:client_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:0", ssl_context: client_context, reuse_port: true)}
	
	it_should_behave_like Async::HTTP::Body
end
