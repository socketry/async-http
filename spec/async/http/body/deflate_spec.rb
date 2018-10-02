#!/usr/bin/env ruby

# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/http/body/writable'
require 'async/http/body/deflate'
require 'async/http/body/inflate'

RSpec.describe Async::HTTP::Body::Deflate do
	let(:body) {Async::HTTP::Body::Writable.new}
	let(:compressed_body) {Async::HTTP::Body::Deflate.for(body)}
	let(:decompressed_body) {Async::HTTP::Body::Inflate.for(compressed_body)}
	
	it "should round-trip data" do
		body.write("Hello World!")
		body.close
		
		expect(decompressed_body.join).to be == "Hello World!"
	end
	
	it "should read chunks" do
		body.write("Hello ")
		body.write("World!")
		body.close
		
		expect(body.read).to be == "Hello "
		expect(body.read).to be == "World!"
		expect(body.read).to be == nil
	end
	
	it "should round-trip chunks" do
		body.write("Hello ")
		body.write("World!")
		body.close
		
		expect(decompressed_body.read).to be == "Hello "
		expect(decompressed_body.read).to be == "World!"
		expect(decompressed_body.read).to be == nil
	end
end
