# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'etc'
require 'benchmark'

RSpec.describe Async::HTTP::Server do
	let(:endpoint) {
		Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true)
	}
	
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:server_url) {"http://127.0.0.1:9294/"}
	
	let(:concurrency) {Etc.nprocessors rescue 2}
	
	# TODO making this higher causes issues in connect - what's the issue?
	let(:repeats) {100}
	
	let(:client) {Async::HTTP::Client.new(endpoint, protocol)}
	
	describe "simple response" do
		it "runs quickly" do
			server = Async::HTTP::Server.new(endpoint, protocol)

			pids = concurrency.times.collect do
				fork do
					Async::Reactor.run do
						server.run
					end
				end
			end
			
			# duration = Benchmark.realtime do
			# 	Async::Reactor.run do |task|
			# 		concurrency.times do
			# 			task.async do
			# 				repeats.times do
			# 					response = client.get("/")
			# 					expect(response).to be_success
			# 				end
			# 			end
			# 		end
			# 	end
			# end
			# 	
			# puts "#{concurrency*repeats} requests in #{duration}s: #{(concurrency*repeats)/duration}req/s"
			
			if ab = `which ab`.chomp!
				puts [ab, "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, server_url].join(' ')
				system(ab, "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, server_url)
			end
			
			if wrk = `which wrk`.chomp!
				system(wrk, "-c", concurrency.to_s, "-d", "10", "-t", concurrency.to_s, server_url)
			end
			
			pids.each do |pid|
				Process.kill(:KILL, pid)
				Process.wait pid
			end
		end
	end
end
