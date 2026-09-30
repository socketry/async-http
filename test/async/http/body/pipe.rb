# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2020-2026, by Samuel Williams.

require "async"
require "async/http/body/pipe"
require "async/http/body/writable"

require "sus/fixtures/async"
require "io/stream"

describe Async::HTTP::Body::Pipe do
	let(:input) {Async::HTTP::Body::Writable.new}
	let(:pipe) {subject.new(input)}
	
	let(:data) {"Hello World!"}
	
	with "#to_io" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:input_write_duration) {0}
		let(:io) {pipe.to_io}
		
		def before
			super
			
			# input writer task
			Async do |task|
				first, second = data.split(" ")
				input.write("#{first} ")
				sleep(input_write_duration) if input_write_duration > 0
				input.write(second)
				input.close_write
			end
		end
		
		after do
			io.close
		end
		
		it "returns an io socket" do
			expect(io).to be_a(::Socket)
			expect(io.read).to be == data
		end
		
		with "blocking reads" do
			let(:input_write_duration) {0.01}
			
			it "returns an io socket" do
				expect(io.read).to be == data
			end
		end
	end
	
	with "#finish" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:output) {Async::HTTP::Body::Writable.new}
		let(:pipe) {subject.new(input, output)}
		
		it "forwards data written to the socket before closing the output" do
			pipe.to_io.write(data)
			pipe.finish
			
			expect(pipe.to_io).to be(:closed?)
			expect(input).to be(:closed?)
			
			expect(output.read).to be == data
			expect(output.read).to be_nil
		end
	end
	
	with "#close" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:output) {Async::HTTP::Body::Writable.new}
		let(:pipe) {subject.new(input, output)}
		
		it "closes the input when forwarding to the closed socket fails" do
			pipe.to_io.close
			
			# Closing the socket only ends the output:
			expect(output.read).to be_nil
			expect(input).not.to be(:closed?)
			
			input.write(data)
			
			Async::Task.current.with_timeout(1) do
				Async::Task.current.yield until input.closed?
			end
			
			expect(input).to be(:closed?)
		ensure
			pipe.close
		end
	end
	
	with "reactor going out of scope" do
		it "finishes" do
			# ensures pipe background tasks are transient
			Async {pipe}
		end
		
		with "closed pipe" do
			it "finishes" do
				Async {pipe.close}
			end
		end
	end
end
