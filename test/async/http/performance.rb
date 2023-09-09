# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.

require 'async/http/server'
require 'async/http/client'

require_relative 'server_context'
require 'async/container'

require 'etc'

RSpec.shared_examples_for 'client benchmark' do
	let(:endpoint) {Async::HTTP::Endpoint.parse('http://127.0.0.1:9294', timeout: 0.8, reuse_port: true)}
	
	let(:server) do
		Async::HTTP::Server.for(@bound_endpoint) do |request|
			Protocol::HTTP::Response[200, {}, []]
		end
	end
	
	let(:url) {endpoint.url.to_s}
	let(:repeats) {1000}
	let(:concurrency) {Etc.nprocessors || 2}
	
	before do
		Sync do
			# We bind the endpoint before running the server so that we know incoming connections will be accepted:
			@bound_endpoint = Async::IO::SharedEndpoint.bound(endpoint)
		end
		
		# I feel a dedicated class might be better than this hack:
		allow(@bound_endpoint).to receive(:protocol).and_return(endpoint.protocol)
		allow(@bound_endpoint).to receive(:scheme).and_return(endpoint.scheme)
		
		@container = Async::Container.new
		
		GC.disable
		
		@container.run(count: concurrency) do |instance|
			Async do
				instance.ready!
				server.run
			end
		end
		
		@bound_endpoint.close
	end
	
	after do
		@container.stop
		
		GC.enable
	end
	
	it "runs benchmark", timeout: nil do
		if ab = `which ab`.chomp!
			system(ab, "-k", "-n", (concurrency*repeats).to_s, "-c", concurrency.to_s, url)
		end
		
		if wrk = `which wrk`.chomp!
			system(wrk, "-c", concurrency.to_s, "-d", "2", "-t", concurrency.to_s, url)
		end
	end
end

RSpec.describe Async::HTTP::Server do
	describe Protocol::HTTP::Middleware::Okay do
		let(:server) do
			Async::HTTP::Server.new(
				Protocol::HTTP::Middleware::Okay,
				@bound_endpoint
			)
		end
		
		include_examples 'client benchmark'
	end
	
	describe 'multiple chunks' do
		let(:server) do
			Async::HTTP::Server.for(@bound_endpoint) do
				Protocol::HTTP::Response[200, {}, "Hello World".chars]
			end
		end
		
		include_examples 'client benchmark'
	end
end
