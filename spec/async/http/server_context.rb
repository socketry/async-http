# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

# Console.logger.level = Logger::DEBUG

RSpec.shared_context Async::HTTP::Server do
	include_context Async::RSpec::Reactor
	
	let(:protocol) {described_class}
	let(:endpoint) {Async::HTTP::Endpoint.parse('http://127.0.0.1:9294', timeout: 0.8, reuse_port: true)}
	
	let(:retries) {1}
	
	let(:server) do
		Async::HTTP::Server.for(endpoint, protocol: protocol) do |request|
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	before do
		@client = Async::HTTP::Client.new(endpoint, protocol: protocol, retries: retries)
		
		@server_task = Async do
			server.run
		end
	end
	
	after do
		@client.close
		@server_task.stop
	end
	
	let(:client) {@client}
	let(:server_task) {@server_task}
end
