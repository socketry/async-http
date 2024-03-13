# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.
# Copyright, 2023, by Thomas Morgan.

require 'async/http/protocol/http11'
require 'async/http/a_protocol'

describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like Async::HTTP::AProtocol
	
	with 'server' do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		with 'bad requests' do
			def around
				current = Console.logger.level
				Console.logger.fatal!
				
				super
			ensure
				Console.logger.level = current
			end

			it "should fail cleanly when path is empty" do
				response = client.get("")
				
				expect(response.status).to be == 400
			end
		end
		
		with 'head request' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					Protocol::HTTP::Response[200, {}, ["Hello", "World"]]
				end
			end
			
			it "doesn't reply with body" do
				5.times do
					response = client.head("/")
					
					expect(response).to be(:success?)
					expect(response.version).to be == "HTTP/1.1"
					expect(response.body).to be(:empty?)
					expect(response.reason).to be == "OK"
					
					response.read
				end
			end
		end
		
		with 'raw response' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					peer = request.hijack!
					
					peer.write(
						"#{request.version} 200 It worked!\r\n" +
						"connection: close\r\n" +
						"\r\n" +
						"Hello World!"
					)
					peer.close

					nil
				end
			end
			
			it "reads raw response" do
				response = client.get("/")
				
				expect(response.read).to be == "Hello World!"
			end

			it "has access to the http reason phrase" do
				response = client.head("/")

				expect(response.reason).to be == "It worked!"
			end
		end

		with 'empty response after hijack' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					peer = request.hijack!

					peer.write(
						"#{request.version} 200 It worked!\r\n" +
						"connection: close\r\n" +
						"\r\n" +
						"Hello World!"
					)
					peer.close

					::Protocol::HTTP::Response[-1, {}, []]
				end
			end

			it "reads raw response" do
				response = client.get("/")

				expect(response.read).to be == "Hello World!"
			end
		end
	end
end
