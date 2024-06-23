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

require 'async/http/mock'
require 'async/http/endpoint'
require 'async/http/client'

require 'sus/fixtures/async/reactor_context'

describe Async::HTTP::Mock do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:endpoint) {Async::HTTP::Mock::Endpoint.new}
	
	it "can respond to requests" do
		server = Async do
			endpoint.run do |request|
				::Protocol::HTTP::Response[200, [], ["Hello World"]]
			end
		end
		
		client = Async::HTTP::Client.new(endpoint)
		
		response = client.get("/index")
		
		expect(response).to be(:success?)
		expect(response.read).to be == "Hello World"
	end
	
	with 'mocked client' do
		it "can mock a client" do
			server = Async do
				endpoint.run do |request|
					::Protocol::HTTP::Response[200, [], ["Authority: #{request.authority}"]]
				end
			end
			
			mock(Async::HTTP::Client) do |mock|
				replacement_endpoint = self.endpoint
				
				mock.wrap(:new) do |original, original_endpoint, **options|
					original.call(replacement_endpoint.wrap(original_endpoint), **options)
				end
			end
			
			google_endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
			client = Async::HTTP::Client.new(google_endpoint)
			
			response = client.get("/search?q=hello")
			
			expect(response).to be(:success?)
			expect(response.read).to be == "Authority: www.google.com"
		ensure
			response&.close
		end
	end
end
