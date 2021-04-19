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

require 'async/http/body/hijack'

RSpec.describe Async::HTTP::Body::Hijack do
	include_context Async::RSpec::Reactor
	
	let(:content) {"Hello World!"}
	
	describe '#call' do
		let(:stream) {Async::HTTP::Body::Writable.new}
		
		subject do
			described_class.wrap do |stream|
				3.times do 
					stream.write(content)
				end
				stream.close
			end
		end
		
		it "should generate body using direct invocation" do
			subject.call(stream)
			
			3.times do
				expect(stream.read).to be == content
			end
			
			expect(stream.read).to be_nil
			expect(stream).to be_empty
		end
		
		it "should generate body using stream" do
			3.times do
				expect(subject.read).to be == content
			end
			
			expect(subject.read).to be_nil
			
			expect(subject).to be_empty
		end
	end
end
