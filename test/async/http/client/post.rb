# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "sus/fixtures/async/http"

APostRequest = Sus::Shared("a post request") do
	include Sus::Fixtures::Async::HTTP::ServerContext
	let(:protocol) {subject}
	
	let(:app) do
		::Protocol::HTTP::Middleware.for do |request|
			::Protocol::HTTP::Response[200, {}, request.body]
		end
	end
	
	it "can post a fixed length body" do
		$stderr.puts "Connecting to server: #{subject}"
		body = Protocol::HTTP::Body::Buffered.wrap(["Hello, World!"])
		
		begin
			response = client.post("/", body: body)
			
			$stderr.puts "Got response: #{response.inspect}"
			
			expect(response).to be(:success?)
			expect(response.read).to be == "Hello, World!"
		ensure
			response&.finish
		end
	end
end

describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like APostRequest
end

describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like APostRequest
end

describe Async::HTTP::Protocol::HTTP2 do
	it_behaves_like APostRequest
end
