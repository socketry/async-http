# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2020-2024, by Samuel Williams.

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
	
	with "reactor going out of scope" do
		it "finishes" do
			# ensures pipe background tasks are transient
			Async{pipe}
		end
		
		with "closed pipe" do
			it "finishes" do
				Async{pipe.close}
			end
		end
	end
end
