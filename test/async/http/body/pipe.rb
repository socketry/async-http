# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2020-2026, by Samuel Williams.

require "async"
require "async/http/body/pipe"
require "async/http/body/writable"

require "sus/fixtures/async"
require "io/stream"
require "openssl"

describe Async::HTTP::Body::Pipe do
	let(:input) {Async::HTTP::Body::Writable.new}
	let(:output) {Async::HTTP::Body::Writable.new}
	let(:pipe) {subject.new(input, output)}
	
	let(:data) {"Hello World!"}
	
	with "#to_io" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:write_input) {true}
		let(:input_write_duration) {0}
		let(:io) {pipe.to_io}
		
		def before
			super
			
			if write_input
				# input writer task
				Async do |task|
					first, second = data.split(" ")
					input.write("#{first} ")
					sleep(input_write_duration) if input_write_duration > 0
					input.write(second)
					input.close_write
				end
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
		
		with "an open pipe" do
			let(:write_input) {false}
			
			it "closes the pipe when closed" do
				expect(input).not.to be(:closed?)
				expect(output).not.to be(:closed?)
				
				io.close
				
				expect(input).to be(:closed?)
				expect(output).to be(:closed?)
			end
			
			it "closes the pipe through a TLS socket" do
				tls = OpenSSL::SSL::SSLSocket.new(io, OpenSSL::SSL::SSLContext.new)
				tls.sync_close = true
				tls.close
				
				expect(input).to be(:closed?)
				expect(output).to be(:closed?)
			end
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
			
			it "can be closed more than once" do
				Async do
					pipe.close
					pipe.close
				end
			end
		end
	end
end
