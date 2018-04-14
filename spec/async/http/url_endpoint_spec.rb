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

require 'async/http/url_endpoint'

RSpec.describe Async::HTTP::URLEndpoint do
	it "should fail to parse relative url" do
		expect{
			described_class.parse("/foo/bar")
		}.to raise_error(ArgumentError, /absolute/)
	end
end

RSpec.describe "http://www.google.com/search" do
	let(:endpoint) {Async::HTTP::URLEndpoint.parse(subject)}
	
	it "should be valid endpoint" do
		expect{endpoint}.to_not raise_error
	end
	
	it "should select the correct protocol" do
		expect(endpoint.protocol).to be Async::HTTP::Protocol::HTTP1
	end
	
	it "should parse the correct hostname" do
		expect(endpoint.hostname).to be == "www.google.com"
	end
end
