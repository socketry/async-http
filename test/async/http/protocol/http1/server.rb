# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http1/server"

require "async/promise"
require "protocol/http/body/buffered"
require "protocol/http/body/wrapper"
require "sus/fixtures/async/reactor_context"

describe Async::HTTP::Protocol::HTTP1::Server do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:server_class) do
		Class.new(subject) do
			attr :next_request_count
			
			def initialize(error = nil)
				super(nil, "HTTP/1.1")
				
				@error = error
				@next_request_count = 0
				@request = Async::HTTP::Protocol::HTTP1::Request.new(
					self,
					nil,
					"localhost",
					"GET",
					"/",
					"HTTP/1.1",
					Protocol::HTTP::Headers.new,
					nil,
				)
			end
			
			def next_request
				@next_request_count += 1
				
				request = @request
				@request = nil
				return request
			end
			
			def write_response(...)
			end
			
			def write_body(...)
				if @error
					raise Protocol::HTTP::RemoteError, @error.message, cause: @error
				end
			end
			
			def hijacked?
				false
			end
		end
	end
	
	let(:body_closed) {Async::Promise.new}
	
	let(:body) do
		body_closed = self.body_closed
		
		Class.new(Protocol::HTTP::Body::Wrapper) do
			define_method(:close) do |error = nil|
				body_closed.resolve(error)
				super(error)
			end
		end.new(Protocol::HTTP::Body::Buffered.wrap("Hello World"))
	end
	
	[Errno::EPIPE, Errno::ECONNRESET].each do |error_class|
		it "handles #{error_class} reported as a remote error", unique: error_class.name do
			error = error_class.new
			server = server_class.new(error)
			
			server.each do
				Protocol::HTTP::Response[200, {}, body]
			end
			
			expect(server.next_request_count).to be == 1
			
			expect(body_closed.wait).to be_a(Protocol::HTTP::RemoteError).and(
				have_attributes(cause: be_equal(error))
			)
		end
	end
	
	it "propagates errors raised while generating the response" do
		server = server_class.new
		
		expect do
			server.each do
				raise Errno::EPIPE
			end
		end.to raise_exception(Errno::EPIPE)
	end
end
