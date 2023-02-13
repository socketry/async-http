# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2019-2020, by Brian Morearty.

require_relative 'server_context'

require 'async/http/relative_location'
require 'async/http/server'

RSpec.describe Async::HTTP::RelativeLocation do
	include_context Async::HTTP::Server
	let(:protocol) {Async::HTTP::Protocol::HTTP1}
	
	subject {described_class.new(@client, 1)}
	
	context 'server redirections' do
		context '301' do
			let(:server) do
				Async::HTTP::Server.for(@bound_endpoint) do |request|
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
				response = subject.post('/')
				
				expect(response).to be_success
				expect(response.read).to be == "GET"
			end
			
			context 'limiting redirects' do
				it 'should allow the maximum number of redirects' do
					response = subject.get('/')
					response.finish
					expect(response).to be_success
				end
				
				it 'should fail with maximum redirects' do
					expect{
						response = subject.get('/home')
					}.to raise_error(Async::HTTP::TooManyRedirects, /maximum/)
				end
			end
		end
		
		context '302' do
			let(:server) do
				Async::HTTP::Server.for(@bound_endpoint) do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[302, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
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
				Async::HTTP::Server.for(@bound_endpoint) do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[307, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
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
				Async::HTTP::Server.for(@bound_endpoint) do |request|
					case request.path
					when '/'
						Protocol::HTTP::Response[308, {'location' => '/index.html'}, []]
					when '/index.html'
						Protocol::HTTP::Response[200, {}, [request.method]]
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
