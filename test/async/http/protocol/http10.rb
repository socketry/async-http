# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.

require "async/http/protocol/http10"
require "async/http/a_protocol"

require "protocol/http/body/writable"

describe Async::HTTP::Protocol::HTTP10 do
	it_behaves_like Async::HTTP::AProtocol
	
	with "request body of unknown length" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		
		let(:protocol) {subject}
		
		let(:paths) {[]}
		
		let(:app) do
			::Protocol::HTTP::Middleware.for do |request|
				paths << request.path
				
				::Protocol::HTTP::Response[200, {}, [request.path]]
			end
		end
		
		it "fails rather than writing the body where the server expects the next request" do
			# HTTP/1.0 has no chunked encoding, and a request body cannot be delimited by closing the connection, so without a content length the server would parse these bytes as a second request:
			body = ::Protocol::HTTP::Body::Writable.new
			body.write "GET /smuggled HTTP/1.1\r\nhost: localhost\r\n\r\n"
			body.close_write
			
			response = nil
			
			# The body is written in a child task which closes the connection on failure, so the error is observed when reading the response:
			expect do
				response = client.post("/", {"connection" => "keep-alive"}, body)
			end.to raise_exception(::Protocol::HTTP1::ProtocolError, message: be =~ /closed/)
			
			expect(body).to be(:closed?)
			
			# The server never saw a complete request, let alone a second one:
			expect(paths).to be(:empty?)
		ensure
			response&.close
		end
	end
end
