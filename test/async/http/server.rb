# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async/http/server"
require "async/http/endpoint"
require "sus/fixtures/async"

describe Async::HTTP::Server do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Endpoint.parse("http://localhost:0")}
	let(:app) {Protocol::HTTP::Middleware::Okay}
	let(:server) {subject.new(app, endpoint)}
	
	with "#run" do
		it "runs the server" do
			task = server.run
			
			expect(task).to be_a(Async::Task)
			
			task.stop
		end
	end
end
