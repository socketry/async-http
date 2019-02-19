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

require_relative 'writable_examples'

require 'async/http/body/slowloris'

RSpec.describe Async::HTTP::Body::Slowloris do
	it_behaves_like Async::HTTP::Body::Writable
	
	it "closes body with error if throughput is not maintained" do
		subject.write("Hello World")
		
		sleep 0.1
		
		expect do
			subject.write("Hello World")
		end.to raise_error(Async::HTTP::Body::Slowloris::ThroughputError, /Slow write/)
	end
	
	it "doesn't close body if throughput is exceeded" do
		subject.write("Hello World")
		
		expect do
			subject.write("Hello World")
		end.to_not raise_error
	end
end
