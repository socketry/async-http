# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.
# Copyright, 2020, by Igor Sidorov.

require 'async'
require 'async/http/client'
require 'async/http/server'
require 'async/http/endpoint'
require 'async/http/body/hijack'
require 'tempfile'

require 'async/http/protocol/http10'
require 'sus/fixtures/async/http/server_context'

AGracefulStop = Sus::Shared("a graceful stop") do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:chunks) {Async::Queue.new}
	
	with 'a streaming server (defered stop body)' do
		let(:app) do
			::Protocol::HTTP::Middleware.for do |request|
				body = ::Async::HTTP::Body::Writable.new
				
				Async do |task|
					task.defer_stop do
						while chunk = chunks.dequeue
							body.write(chunk)
						end
					end
				ensure
					body.close($!)
				end
				
				::Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		it "should stop gracefully" do
			response = client.get("/")
			expect(response).to be(:success?)
			
			@server_task.stop
			
			chunks.enqueue("Hello, World!")
			expect(response.body.read).to be == "Hello, World!"
			chunks.enqueue(nil)
		ensure
			response&.close
		end
	end
	
	with 'a streaming server' do
		let(:app) do
			::Protocol::HTTP::Middleware.for do |request|
				body = ::Async::HTTP::Body::Writable.new
				
				Async do |task|
					while chunk = chunks.dequeue
						body.write(chunk)
					end
				ensure
					body.close($!)
				end
				
				::Protocol::HTTP::Response[200, {}, body]
			end
		end
		
		it "should stop gracefully" do
			response = client.get("/")
			expect(response).to be(:success?)
			
			@server_task.stop
			
			chunks.enqueue("Hello, World!")
			expect do
				response.read
			end.to raise_exception(EOFError)
		end
	end
end

describe Async::HTTP::Protocol::HTTP11 do
	it_behaves_like AGracefulStop
end
