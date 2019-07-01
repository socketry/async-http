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

require 'rack/test'

require 'async'
require 'async/http'

RSpec.describe Rack::Test do
	include_context Async::RSpec::Reactor
	include Rack::Test::Methods
	
	let(:app) do
		Rack::Builder.new do
			def body(*chunks)
				body = Async::HTTP::Body::Writable.new
				
				Async do |task|
					chunks.each do |chunk|
						body.write(chunk)
						task.sleep(0.1)
					end
					
					body.close
				end
				
				return body
			end
			
			# This echos the body back.
			run lambda { |env| [200, {}, body("Hello", " ", "World", "!")] }
		end
	end
	
	it "can read response body" do
		get "/"
		
		expect(last_response.body).to be == "Hello World!"
	end
end
