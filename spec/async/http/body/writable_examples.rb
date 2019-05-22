# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
	include_context Async::RSpec::Reactor
	
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
