# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2"
require "sus/fixtures/async/scheduler_context"
require "socket"

describe Async::HTTP::Protocol::HTTP2::Server do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:sockets) {Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)}
	let(:stream) {IO::Stream(sockets.first)}
	let(:server) {subject.new(stream)}
	
	it "closes the request queue" do
		request = Object.new
		server.requests.enqueue(request)
		
		server.close
		
		expect(server.requests).to be(:closed?)
		expect(server.requests.dequeue).to be == request
		expect(server.requests.dequeue).to be_nil
		
		expect do
			server.requests.enqueue(Object.new)
		end.to raise_exception(Async::Queue::ClosedError)
	end
end
