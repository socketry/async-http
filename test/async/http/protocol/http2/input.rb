# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2/input"

describe Async::HTTP::Protocol::HTTP2::Input do
	let(:stream) do
		Class.new do
			attr_reader :window_updates
			attr_reader :finished_inputs
			
			def initialize
				@window_updates = 0
				@finished_inputs = []
			end
			
			def request_window_update
				@window_updates += 1
			end
			
			def finish_input(input)
				@finished_inputs << input
			end
		end.new
	end
	
	let(:input) {subject.new(stream, nil)}
	
	it "requests a window update when data is consumed" do
		input.write("Hello World")
		
		expect(input.read).to be == "Hello World"
		expect(stream.window_updates).to be == 1
	end
	
	it "notifies the stream when closed" do
		error = RuntimeError.new("Input closed")
		
		input.close(error)
		input.close
		
		expect(stream.finished_inputs).to be == [input]
	end
end
