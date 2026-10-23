# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Andrew Fader.

require "async/http/protocol/http1/finishable"

require "protocol/http/body/buffered"
require "sus/fixtures/async/reactor_context"

describe Async::HTTP::Protocol::HTTP1::Finishable do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:source) {Protocol::HTTP::Body::Buffered.new(["Hello", " ", "World"])}
	let(:finishable) {subject.new(source)}
	
	with "a partially read body" do
		it "discards the rest when the connection is persistent" do
			expect(finishable.read).to be == "Hello"
			
			Async::Task.current.with_timeout(1) do
				finishable.wait(true)
			end
			
			expect(source.read).to be_nil
		end
		
		it "closes it when the connection is not persistent" do
			expect(finishable.read).to be == "Hello"
			
			expect(source).to receive(:close)
			
			Async::Task.current.with_timeout(1) do
				finishable.wait(false)
			end
		end
	end
	
	with "a fully read body" do
		it "returns once it has been closed" do
			expect(finishable.join).to be == "Hello World"
			
			Async::Task.current.with_timeout(1) do
				finishable.wait(true)
			end
		end
	end
end
