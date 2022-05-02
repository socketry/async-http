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

require 'async/http/protocol/http2'
require_relative 'shared_examples'

RSpec.describe Async::HTTP::Protocol::HTTP2, timeout: 2 do
	it_behaves_like Async::HTTP::Protocol
	
	context 'bad requests' do
		include_context Async::HTTP::Server
		
		it "should fail with explicit authority" do
			expect do
				client.post("/", [[':authority', 'foo']])
			end.to raise_error(Protocol::HTTP2::StreamError)
		end
	end
	
	context 'closed streams' do
		include_context Async::HTTP::Server
		
		it 'should delete stream after response stream is closed' do
			response = client.get("/")
			connection = response.connection
			
			response.read
			
			expect(connection.streams).to be_empty
		end
	end
	
	context 'host header' do
		include_context Async::HTTP::Server
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				Protocol::HTTP::Response[200, request.headers, ["Authority: #{request.authority.inspect}"]]
			end
		end
		
		# We specify nil for the authority - it won't be sent.
		let!(:client) {Async::HTTP::Client.new(endpoint, authority: nil)}
		
		it "should not send :authority header if host header is present" do
			response = client.post("/", [['host', 'foo']])
			
			expect(response.headers).to include('host')
			expect(response.headers['host']).to be == 'foo'
			
			# TODO Should HTTP/2 respect host header?
			expect(response.read).to be == "Authority: nil"
		end
	end
	
	context 'stopping requests' do
		include_context Async::HTTP::Server
		
		let(:notification) {Async::Notification.new}
		
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do |request|
				body = Async::HTTP::Body::Writable.new
				
				reactor.async do |task|
					begin
						100.times do |i|
							body.write("Chunk #{i}")
							task.sleep (0.01)
						end
					rescue
						# puts "Response generation failed: #{$!}"
					ensure
						body.close
						notification.signal
					end
				end
				
				Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		let(:pool) {client.pool}
		
		it "should close stream without closing connection" do
			expect(pool).to be_empty
			
			response = client.get("/")
			
			expect(pool).to_not be_empty
			
			response.close
			
			notification.wait
			
			expect(response.stream.connection).to be_reusable
		end
	end
end
