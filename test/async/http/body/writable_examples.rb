# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

require 'async/http/body'
require 'protocol/http/body/deflate'
require 'async/http/body/writable'
require 'async/http/endpoint'

require 'async/io/ssl_socket'
require 'async/rspec/ssl'

RSpec.shared_examples_for Async::HTTP::Body::Writable do
	it "can write and read data" do
		3.times do |i|
			subject.write("Hello World #{i}")
			expect(subject.read).to be == "Hello World #{i}"
		end
	end
	
	it "can buffer data in order" do
		3.times do |i|
			subject.write("Hello World #{i}")
		end
		
		3.times do |i|
			expect(subject.read).to be == "Hello World #{i}"
		end
	end
	
	context '#join' do
		it "can join chunks" do
			3.times do |i|
				subject.write("#{i}")
			end
			
			subject.close
			
			expect(subject.join).to be == "012"
		end
	end
	
	context '#each' do
		it "can read all data in order" do
			3.times do |i|
				subject.write("Hello World #{i}")
			end
			
			subject.close
			
			3.times do |i|
				chunk = subject.read
				expect(chunk).to be == "Hello World #{i}"
			end
		end
		
		it "can propagate failures" do
			reactor.async do
				expect do
					subject.each do |chunk|
						raise RuntimeError.new("It was too big!")
					end
				end.to raise_error(RuntimeError, /big/)
			end
			
			expect{
				subject.write("Beep boop") # This will cause a failure.
				Async::Task.current.yield
				subject.write("Beep boop") # This will fail.
			}.to raise_error(RuntimeError, /big/)
		end
		
		it "can propagate failures in nested bodies" do
			nested = Protocol::HTTP::Body::Deflate.for(subject)
			
			reactor.async do
				expect do
					nested.each do |chunk|
						raise RuntimeError.new("It was too big!")
					end
				end.to raise_error(RuntimeError, /big/)
			end
			
			expect{
				subject.write("Beep boop") # This will cause a failure.
				Async::Task.current.yield
				subject.write("Beep boop") # This will fail.
			}.to raise_error(RuntimeError, /big/)
		end
		
		it "will stop after finishing" do
			output_task = reactor.async do
				subject.each do |chunk|
					expect(chunk).to be == "Hello World!"
				end
			end
			
			subject.write("Hello World!")
			subject.close
			
			expect(subject).to_not be_empty
			
			Async::Task.current.yield
			
			expect(output_task).to be_finished
			expect(subject).to be_empty
		end
	end
end
