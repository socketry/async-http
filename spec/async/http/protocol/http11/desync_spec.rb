# Copyright, 2021, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative '../../server_context'
require 'async/http/protocol/http11'

RSpec.describe Async::HTTP::Protocol::HTTP11, timeout: 30 do
	include_context Async::HTTP::Server
	
	let(:server) do
		Async::HTTP::Server.for(endpoint, protocol: protocol) do |request|
			Protocol::HTTP::Response[200, {}, [request.path]]
		end
	end
	
	around do |example|
		current = Console.logger.level
		Console.logger.fatal!
		
		example.run
	ensure
		Console.logger.level = current
	end
	
	it "doesn't desync responses" do
		tasks = []
		task = Async::Task.current
		
		response = client.get("/a")
		expect(response.read).to be == "/a"
		
		response = client.get("/b")
		expect(response.read).to be == "/b"
		
		100.times do
			tasks << task.async{
				loop do
					response = client.get('/a')
					expect(response.read).to be == "/a"
				ensure
					response&.close
				end
			}
		end
		
		100.times do
			tasks << task.async{
				loop do
					response = client.get('/b')
					expect(response.read).to be == "/b"
				ensure
					response&.close
				end
			}
		end
		
		tasks.each do |task|
			task.sleep 0.01
			task.stop
		end
	end
end
