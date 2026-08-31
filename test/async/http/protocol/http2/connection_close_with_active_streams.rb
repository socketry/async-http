# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/scheduler_context"
require "socket"

describe Async::HTTP::Protocol::HTTP2 do
	include Sus::Fixtures::Async::SchedulerContext
	
	with "connection closing with active streams" do
		let(:sockets) {Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)}
		let(:client_stream) {IO::Stream(sockets.first)}
		
		it "raises error when connection closes with active streams waiting for headers" do
			Async do |task|
				# Create client connection
				client_connection = Async::HTTP::Protocol::HTTP2::Client.new(client_stream)
				# Open the connection (skip preface for unit test)
				client_connection.open!
				
				# Create a response stream (simulating a request that's been sent but headers not yet received):
				response = client_connection.create_response
				
				# Verify the response exists and has nil status (headers not received yet):
				expect(response.status).to be_nil
				expect(response.headers).to be_nil
				expect(response.body).to be_nil
				
				# Verify there's an active stream:
				expect(client_connection.streams).not.to be(:empty?)
				expect(client_connection.streams.size).to be == 1
				
				# Simulate connection closing cleanly (like EOF from server timeout)
				# This should generate an error for active streams
				client_connection.close(nil)
				
				# The stream should have been notified with an error
				# Try to wait for the response - should raise EOFError
				expect do
					response.wait
				end.to raise_exception(EOFError, message: be =~ /Connection closed with .* active stream/)
				
				# Verify the response still has nil values (it was never populated)
				expect(response.status).to be_nil
				expect(response.headers).to be_nil
			end.wait
		end
		
		it "maps a remote internal error while waiting for headers" do
			Async do |task|
				client_connection = Async::HTTP::Protocol::HTTP2::Client.new(client_stream)
				client_connection.open!
				
				response = client_connection.create_response
				response.stream.close!(Protocol::HTTP2::INTERNAL_ERROR)
				
				expect do
					client_connection.read_response(response)
				end.to raise_exception(Protocol::HTTP::RemoteError).and(
					have_attributes(
						cause: be_a(Protocol::HTTP2::StreamError).and(
							have_attributes(code: be == Protocol::HTTP2::INTERNAL_ERROR)
						)
					)
				)
			end.wait
		end
		
		it "does not raise error when connection closes without active streams" do
			Async do |task|
				# Create client connection
				client_connection = Async::HTTP::Protocol::HTTP2::Client.new(client_stream)
				client_connection.open!
				
				# Verify no active streams
				expect(client_connection.streams).to be(:empty?)
				
				# Close the connection cleanly - should not raise
				client_connection.close(nil)
				
				# Connection should be closed
				expect(client_connection).to be(:closed?)
			end.wait
		end
		
		it "refuses a request when the connection is already closed" do
			Async do
				client_connection = Async::HTTP::Protocol::HTTP2::Client.new(client_stream)
				client_connection.open!
				client_connection.close
				
				expect do
					client_connection.call(Protocol::HTTP::Request["POST", "/", {}, ["Hello"]])
				end.to raise_exception(Protocol::HTTP::RefusedError)
			end.wait
		end
	end
end
