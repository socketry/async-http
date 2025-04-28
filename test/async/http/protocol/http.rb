# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Thomas Morgan.
# Copyright, 2024-2025, by Samuel Williams.

require "async/http/protocol/http"
require "async/http/a_protocol"

describe Async::HTTP::Protocol::HTTP do
	let(:protocol) {subject.default}
	
	with ".default" do
		it "has a default instance" do
			expect(protocol).to be_a Async::HTTP::Protocol::HTTP
		end
	end
	
	with "#protocol_for" do
		let(:buffer) {StringIO.new}
		
		it "it can detect http/1.1" do
			buffer.write("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
			buffer.rewind
			
			stream = IO::Stream(buffer)
			
			expect(protocol.protocol_for(stream)).to be == Async::HTTP::Protocol::HTTP1
		end
		
		it "it can detect http/2" do
			# This special preface is used to indicate that the client would like to use HTTP/2.
			# https://www.rfc-editor.org/rfc/rfc7540.html#section-3.5
			buffer.write("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
			buffer.rewind
			
			stream = IO::Stream(buffer)
			
			expect(protocol.protocol_for(stream)).to be == Async::HTTP::Protocol::HTTP2
		end
	end
	
	with "server" do
		include Sus::Fixtures::Async::HTTP::ServerContext
		let(:protocol) {subject}
		
		with "http11 client" do
			it "should make a successful request" do
				response = client.get("/")
				expect(response).to be(:success?)
				expect(response.version).to be == "HTTP/1.1"
				response.read
			end
		end
		
		with "http2 client" do
			def make_client(endpoint, **options)
				options[:protocol] = Async::HTTP::Protocol::HTTP2
				super
			end
			
			it "should make a successful request" do
				response = client.get("/")
				expect(response).to be(:success?)
				expect(response.version).to be == "HTTP/2"
				response.read
			end
		end
	end
end
