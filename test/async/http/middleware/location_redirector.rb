# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2019-2020, by Brian Morearty.

require 'async/http/middleware/location_redirector'
require 'async/http/server'

require 'sus/fixtures/async/http'

describe Async::HTTP::Middleware::LocationRedirector do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:relative_location) {subject.new(@client, 1)}
	
	with 'server redirections' do
		with '301' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					request.finish # TODO: request.discard - or some default handling?
					
					case request.path
					when '/home'
						Protocol::HTTP::Response[301, {'location' => '/'}, []]
					when '/'
						Protocol::HTTP::Response[301, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect POST to GET' do
				body = Protocol::HTTP::Body::Buffered.wrap(["Hello, World!"])
				expect(body).to receive(:finish)
				
				response = relative_location.post('/', {}, body)
				
				expect(response).to be(:success?)
				expect(response.read).to be == "GET"
			end
			
			with 'limiting redirects' do
				it 'should allow the maximum number of redirects' do
					response = relative_location.get('/')
					response.finish
					expect(response).to be(:success?)
				end
				
				it 'should fail with maximum redirects' do
					expect do
						response = relative_location.get('/home')
					end.to raise_exception(subject::TooManyRedirects, message: be =~ /maximum/)
				end
			end
			
			with "handle_redirect returning false" do
				before do
					expect(relative_location).to receive(:handle_redirect).and_return(false)
				end
				
				it "should not follow the redirect" do
					response = relative_location.get('/')
					response.finish
					
					expect(response).to be(:redirection?)
				end
			end
		end
		
		with '302' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[302, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect POST to GET' do
				response = relative_location.post('/')
				
				expect(response).to be(:success?)
				expect(response.read).to be == "GET"
			end
		end
		
		with '307' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[307, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect with same method' do
				response = relative_location.post('/')
				
				expect(response).to be(:success?)
				expect(response.read).to be == "POST"
			end
		end
		
		with '308' do
			let(:app) do
				Protocol::HTTP::Middleware.for do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[308, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
					end
				end
			end
			
			it 'should redirect with same method' do
				response = relative_location.post('/')
				
				expect(response).to be(:success?)
				expect(response.read).to be == "POST"
			end
		end
	end
end
