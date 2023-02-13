# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.

require 'async/http/protocol/http11'
require_relative 'shared_examples'

RSpec.describe Async::HTTP::Protocol::HTTP11, timeout: 2 do
	it_behaves_like Async::HTTP::Protocol
	
	context 'head request' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, {}, ["Hello", "World"]]
			end
		end
		
		it "doesn't reply with body" do
			5.times do
				response = client.head("/")
				
				expect(response).to be_success
				expect(response.version).to be == "HTTP/1.1"
				expect(response.body).to be_empty
				
				response.read
			end
		end
	end
	
	context 'raw response' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
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
	end
end
