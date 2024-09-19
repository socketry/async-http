# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async/http/mock"
require "async/http/endpoint"
require "async/http/client"

require "sus/fixtures/async/reactor_context"

describe Async::HTTP::Mock do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Mock::Endpoint.new}
	
	it "can respond to requests" do
		server = Async do
			endpoint.run do |request|
				::Protocol::HTTP::Response[200, [], ["Hello World"]]
			end
		end
		
		client = Async::HTTP::Client.new(endpoint)
		
		response = client.get("/index")
		
		expect(response).to be(:success?)
		expect(response.read).to be == "Hello World"
	end
	
	with "mocked client" do
		it "can mock a client" do
			server = Async do
				endpoint.run do |request|
					::Protocol::HTTP::Response[200, [], ["Authority: #{request.authority}"]]
				end
			end
			
			mock(Async::HTTP::Client) do |mock|
				replacement_endpoint = self.endpoint
				
				mock.wrap(:new) do |original, original_endpoint, **options|
					original.call(replacement_endpoint.wrap(original_endpoint), **options)
				end
			end
			
			google_endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
			client = Async::HTTP::Client.new(google_endpoint)
			
			response = client.get("/search?q=hello")
			
			expect(response).to be(:success?)
			expect(response.read).to be == "Authority: www.google.com"
		ensure
			response&.close
		end
	end
end
