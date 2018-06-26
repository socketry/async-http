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

require 'async/http/relative_location'
require 'async/http/server'

RSpec.describe Async::HTTP::RelativeLocation do
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9294', reuse_port: true)}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	subject {described_class.new(client)}
	
	context 'server redirections' do
		include_context Async::RSpec::Reactor
		
		let!(:server_task) do
			reactor.async do
				server.run
			end
		end
		
		after(:each) do
			server_task.stop
			subject.close
		end
		
		context '301' do
			let(:server) do
				Async::HTTP::Server.for(endpoint) do |request|
					case request.path
					when '/'
						Async::HTTP::Response[301, {'location' => '/index.html'}, []]
					when '/forever'
						Async::HTTP::Response[301, {'location' => '/forever'}, []]
					when '/index.html'
						Async::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect POST to GET' do
				response = subject.post('/')
				
				expect(response).to be_success
				expect(response.read).to be == "GET"
			end
			
			it 'should fail with maximum redirects' do
				expect{
					response = subject.get('/forever')
				}.to raise_error(ArgumentError, /maximum/)
			end
		end
		
		context '302' do
			let(:server) do
				Async::HTTP::Server.for(endpoint) do |request|
					case request.path
					when '/'
						Async::HTTP::Response[302, {'location' => '/index.html'}, []]
					when '/index.html'
						Async::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect POST to GET' do
				response = subject.post('/')
				
				expect(response).to be_success
				expect(response.read).to be == "GET"
			end
		end
		
		context '307' do
			let(:server) do
				Async::HTTP::Server.for(endpoint) do |request|
					case request.path
					when '/'
						Async::HTTP::Response[307, {'location' => '/index.html'}, []]
					when '/index.html'
						Async::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect with same method' do
				response = subject.post('/')
				
				expect(response).to be_success
				expect(response.read).to be == "POST"
			end
		end
		
		context '308' do
			let(:server) do
				Async::HTTP::Server.for(endpoint) do |request|
					case request.path
					when '/'
						Async::HTTP::Response[308, {'location' => '/index.html'}, []]
					when '/index.html'
						Async::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect with same method' do
				response = subject.post('/')
				
				expect(response).to be_success
				expect(response.read).to be == "POST"
			end
		end
	end
end
