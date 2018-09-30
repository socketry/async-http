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

require 'async/http/body/chunked'
require 'async/io/stream'

RSpec.describe Async::HTTP::Body::Chunked do
	include_context Async::RSpec::Memory
	
	let(:content) {"Hello World"}
	let(:io) {StringIO.new("#{content.bytesize.to_s(16)}\r\n#{content}\r\n0\r\n\r\n")}
	let(:stream) {Async::IO::Stream.new(io)}
	let(:protocol) {Async::HTTP::Protocol::HTTP11.client(stream)}
	subject! {described_class.new(protocol)}
	
	describe "#empty?" do
		it "returns whether EOF was reached" do
			expect(subject.empty?).to be == false
		end
	end
	
	describe "#stop" do
		it "closes the stream" do
			subject.stop(:error)
			expect(stream).to be_closed
		end
		
		it "marks body as finished" do
			subject.stop(:error)
			expect(subject).to be_empty
		end
	end
	
	describe "#read" do
		it "retrieves chunks of content" do
			expect(subject.read).to be == "Hello World"
			expect(subject.read).to be == nil
			expect(subject.read).to be == nil
		end
		
		it "updates number of bytes retrieved" do
			subject.read
			subject.read # realizes there are no more chunks
			expect(subject).to be_empty
		end
		
		context "with large stream" do
			let!(:content) {"a" * 5*1024*1024}
			
			it "allocates expected amount of memory" do
				expect do
					while chunk = subject.read
						chunk.clear
					end
				end.to limit_allocations.of(String, size: 0)
			end
		end
	end
end
