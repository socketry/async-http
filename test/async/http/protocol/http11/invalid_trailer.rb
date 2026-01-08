# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "async/http/a_protocol"

describe Async::HTTP::Protocol::HTTP11 do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:protocol) {subject}
	
	with "invalid trailers" do
		let(:app) do
			Protocol::HTTP::Middleware.for do |request|
				Protocol::HTTP::Response[200, [], request.body]
			end
		end
		
		it "rejects host header as trailer" do
			headers = ::Protocol::HTTP::Headers.new([["host", "example.com"]], 0)
			
			body = Async::HTTP::Body::Writable.new
			
			response = client.post("/", headers, body)
			
			body.write("Hello world!")
			body.close_write
			
			expect do
				response.read
			end.to raise_exception(EOFError)
		end
	end
end
