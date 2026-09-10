# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Tavian Barnes.

require "async/http/protocol/http2/output"
require "async/http/body/writable"

require "sus/fixtures/async"

describe Async::HTTP::Protocol::HTTP2::Output do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:stream) do
		Class.new do
			def initialize
				@errors = []
			end
			
			attr :errors
			
			def finish_output(error = nil)
				@errors << error
			end
		end.new
	end
	
	let(:body) {Async::HTTP::Body::Writable.new}
	
	let(:output) {subject.new(stream, body)}
	
	it "propagates cancellation when the task is cancelled" do
		task = output.start
		
		task.cancel
		task.wait
		
		expect(stream.errors.size).to be == 1
		expect(stream.errors.first).to be_a(Async::Cancel)
	end
end
