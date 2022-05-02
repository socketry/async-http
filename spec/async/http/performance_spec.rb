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

require_relative 'server_context'
require 'async/container'

require 'etc'

RSpec.shared_examples_for 'client benchmark' do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('http://127.0.0.1:9294', timeout: 0.8, reuse_port: true)}
	
	let(:server) do
		Async::HTTP::Server.for(@bound_endpoint) do |request|
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	let(:url) {endpoint.url.to_s}
	let(:repeats) {1000}
	let(:concurrency) {Etc.nprocessors || 2}
	
	before do
		# We bind the endpoint before running the server so that we know incoming connections will be accepted:
		@bound_endpoint = Async::IO::SharedEndpoint.bound(endpoint)
		
		# I feel a dedicated class might be better than this hack:
		allow(@bound_endpoint).to receive(:protocol).and_return(endpoint.protocol)
		allow(@bound_endpoint).to receive(:scheme).and_return(endpoint.scheme)
		
		@container = Async::Container.new
		
		GC.disable
		
		@container.run(count: concurrency) do |instance|
			Async do
				instance.ready!
				server.run
			end
		end
		
		@bound_endpoint.close
	end
	
	after do
		@container.stop
		
		GC.enable
	end
	
	it "runs benchmark", timeout: nil do
		if ab = `which ab`.chomp!
			system(ab, "-k", "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, url)
		end
		
		if wrk = `which wrk`.chomp!
			system(wrk, "-c", concurrency.to_s, "-d", "2", "-t", concurrency.to_s, url)
		end
	end
end

RSpec.describe Async::HTTP::Server do
	describe Protocol::HTTP::Middleware::Okay do
		let(:server) do
			Async::HTTP::Server.new(
				Protocol::HTTP::Middleware::Okay,
				@bound_endpoint
			)
		end
		
		include_examples 'client benchmark'
	end
	
	describe 'multiple chunks' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do
				Protocol::HTTP::Response[200, {}, "Hello World".chars]
			end
		end
		
		include_examples 'client benchmark'
	end
end
