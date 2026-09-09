# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Tavian Barnes.

require "async/http/protocol/http2/output"
require "async/http/body/writable"

require "sus/fixtures/async"

describe Async::HTTP::Protocol::HTTP2::Output do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:io) do
		Class.new do
			def initialize
				@closed = false
			end
			
			def close
				@closed = true
			end
			
			def closed?
				@closed
			end
		end.new
	end
	
	let(:connection) do
		Class.new do
			def initialize(io)
				@stream = Struct.new(:io).new(io)
				@closed = false
			end
			
			attr :stream
			
			def close(error = nil)
				@closed = true
			end
			
			def closed?
				@closed
			end
		end.new(io)
	end
	
	let(:stream) do
		Class.new do
			def initialize(connection)
				@connection = connection
				@errors = []
			end
			
			attr :connection
			attr :errors
			
			def finish_output(error = nil)
				@errors << error
			end
		end.new(connection)
	end
	
	let(:body) {Async::HTTP::Body::Writable.new}
	
	let(:output) {subject.new(stream, body)}
	
	it "resets the stream when the task is cancelled" do
		task = output.start
		
		task.cancel
		task.wait
		
		expect(stream.errors.size).to be == 1
		expect(stream.errors.first).to be_a(Async::Cancel)
	end
	
	with "a stream which blocks while finishing output" do
		let(:stream) do
			Class.new do
				def initialize(connection)
					@connection = connection
				end
				
				attr :connection
				
				def finish_output(error = nil)
					sleep
				end
			end.new(connection)
		end
		
		it "closes the connection when the task is cancelled" do
			task = output.start
			
			task.cancel
			
			Async::Task.current.with_timeout(5) do
				task.wait
			end
			
			expect(io).to be(:closed?)
			expect(connection).to be(:closed?)
		end
	end
end
