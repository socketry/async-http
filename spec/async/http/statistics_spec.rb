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

require 'async/http/statistics'

RSpec.describe Async::HTTP::Statistics, timeout: 5 do
	include_context Async::HTTP::Server
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	let(:server) do
		Async::HTTP::Server.for(endpoint, protocol) do |request|
			statistics = described_class.start
			
			response = Async::HTTP::Response[200, {}, ["Hello ", "World!"]]
			
			statistics.wrap(response) do |statistics, error|
				expect(statistics.sent).to be == 12
				expect(error).to be_nil
			end
		end
	end
	
	it "client can get resource" do
		response = client.get("/")
		expect(response.read).to be == "Hello World!"
		
		expect(response).to be_success
	end
end
