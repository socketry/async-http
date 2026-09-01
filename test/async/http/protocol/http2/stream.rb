# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http2/stream"

describe Async::HTTP::Protocol::HTTP2::Stream do
	let(:output) do
		Class.new do
			def close_stream
			end
			
			def stop(error)
			end
		end.new
	end
	
	let(:stream) do
		Class.new(subject) do
			def initialize(output)
				@input = nil
				@output = output
				@pool = nil
				@connection = nil
			end
		end.new(output)
	end
	
	it "closes the output stream on an orderly closure" do
		expect(output).to receive(:close_stream)
		
		stream.closed(nil)
	end
	
	it "stops the output stream on an error" do
		error = RuntimeError.new("Stream failed!")
		expect(output).to receive(:stop).with(error)
		
		stream.closed(error)
	end
end
