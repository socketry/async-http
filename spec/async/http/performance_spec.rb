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

require 'async/http/endpoint'
require 'async/io/shared_endpoint'
require 'async/reactor'

require 'async/container/forked'

require 'etc'
require 'benchmark'

RSpec.describe Async::HTTP::Server do
	let(:endpoint) {Async::HTTP::Endpoint.parse("http://127.0.0.1:9294")}
	let(:url) {endpoint.url.to_s}
	
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:concurrency) {Etc.nprocessors rescue 2}
	
	# TODO making this higher causes issues in connect - what's the issue?
	let(:repeats) {200}
	
	let(:client) {Async::HTTP::Client.new(endpoint, protocol)}
	
	before(:all) do
		GC.disable
	end
	
	after(:all) do
		GC.enable
	end
	
	describe "simple response" do
		it "runs quickly" do
			bound_endpoint = nil
			
			Async::Reactor.run do
				bound_endpoint = Async::IO::SharedEndpoint.bound(endpoint)
			end
			
			server = Async::HTTP::Server.new(
				Protocol::HTTP::Middleware::Okay,
				bound_endpoint, protocol, endpoint.scheme
			)
			
			container = Async::Container::Forked.new(concurrency: concurrency) do
				server.run
			end
			
			bound_endpoint.close if bound_endpoint
			
			if ab = `which ab`.chomp!
				# puts [ab, "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, url].join(' ')
				system(ab, "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, url)
			end
			
			if wrk = `which wrk`.chomp!
				system(wrk, "-c", concurrency.to_s, "-d", "2", "-t", concurrency.to_s, url)
			end
			
			container.stop(:KILL)
		end
	end
end
