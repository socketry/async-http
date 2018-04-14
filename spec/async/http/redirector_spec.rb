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

require 'async/http/redirector'
require 'async/http/server'

RSpec.describe Async::HTTP::Redirector do
	let(:endpoint) {Async::HTTP::URLEndpoint.parse('http://127.0.0.1:9294', reuse_port: true)}
	let(:client) {Async::HTTP::Client.new(endpoint)}
	
	subject {described_class.new(client)}
	
	context '#lookup' do
		it "should create client" do
			url = URI.parse("http://www.google.com/search?q=ruby")
			client, location = subject.lookup url
			
			expect(client.endpoint.hostname).to be == "www.google.com"
			expect(location).to be == "/search?q=ruby"
		end
		
		it "should reuse client" do
			first_client, first_location = subject["http://www.google.com/search?q=ruby"]
			second_client, second_location = subject["http://www.google.com/search?q=async"]
			
			expect(first_client).to be_equal second_client
		end
		
		it "should create second client" do
			first_client, first_location = subject["http://www.google.com/search?q=ruby"]
			second_client, second_location = subject["http://www.groogle.com/search?q=async"]
			
			expect(first_client).to_not be_equal second_client
		end
	end
	
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
				Async::HTTP::Server.new(endpoint) do |request, peer, address|
					case request.path
					when '/'
						[301, {'location' => '/index.html'}, []]
					when '/forever'
						[301, {'location' => '/forever'}, []]
					when '/index.html'
						[200, {}, [request.method]]
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
				Async::HTTP::Server.new(endpoint) do |request, peer, address|
					case request.path
					when '/'
						[302, {'location' => '/index.html'}, []]
					when '/index.html'
						[200, {}, [request.method]]
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
				Async::HTTP::Server.new(endpoint) do |request, peer, address|
					case request.path
					when '/'
						[307, {'location' => '/index.html'}, []]
					when '/index.html'
						[200, {}, [request.method]]
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
				Async::HTTP::Server.new(endpoint) do |request, peer, address|
					case request.path
					when '/'
						[308, {'location' => '/index.html'}, []]
					when '/index.html'
						[200, {}, [request.method]]
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
