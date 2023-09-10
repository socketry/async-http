# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http/body/deflate'

module Async
	module HTTP
		module Body
			AWritableBody = Sus::Shared("a writable body") do
				it "can write and read data" do
					3.times do |i|
						body.write("Hello World #{i}")
						expect(body.read).to be == "Hello World #{i}"
					end
				end
				
				it "can buffer data in order" do
					3.times do |i|
						body.write("Hello World #{i}")
					end
					
					3.times do |i|
						expect(body.read).to be == "Hello World #{i}"
					end
				end
				
				with '#join' do
					it "can join chunks" do
						3.times do |i|
							body.write("#{i}")
						end
						
						body.close
						
						expect(body.join).to be == "012"
					end
				end
				
				with '#each' do
					it "can read all data in order" do
						3.times do |i|
							body.write("Hello World #{i}")
						end
						
						body.close
						
						3.times do |i|
							chunk = body.read
							expect(chunk).to be == "Hello World #{i}"
						end
					end
					
					it "can propagate failures" do
						reactor.async do
							expect do
								body.each do |chunk|
									raise RuntimeError.new("It was too big!")
								end
							end.to raise_exception(RuntimeError, message: be =~ /big/)
						end
						
						expect{
							body.write("Beep boop") # This will cause a failure.
							::Async::Task.current.yield
							body.write("Beep boop") # This will fail.
						}.to raise_exception(RuntimeError, message: be =~ /big/)
					end
					
					it "can propagate failures in nested bodies" do
						nested = ::Protocol::HTTP::Body::Deflate.for(body)
						
						reactor.async do
							expect do
								nested.each do |chunk|
									raise RuntimeError.new("It was too big!")
								end
							end.to raise_exception(RuntimeError, message: be =~ /big/)
						end
						
						expect{
							body.write("Beep boop") # This will cause a failure.
							::Async::Task.current.yield
							body.write("Beep boop") # This will fail.
						}.to raise_exception(RuntimeError, message: be =~ /big/)
					end
					
					it "will stop after finishing" do
						output_task = reactor.async do
							body.each do |chunk|
								expect(chunk).to be == "Hello World!"
							end
						end
						
						body.write("Hello World!")
						body.close
						
						expect(body).not.to be(:empty?)
						
						::Async::Task.current.yield
						
						expect(output_task).to be(:finished?)
						expect(body).to be(:empty?)
					end
				end
			end
		end
	end
end
