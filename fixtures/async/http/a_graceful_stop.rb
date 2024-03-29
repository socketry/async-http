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

module Async
	module HTTP
		AGracefulStop = Sus::Shared("a graceful stop") do
			include Sus::Fixtures::Async::HTTP::ServerContext
			
			let(:events) {Async::Queue.new}
			
			with 'a streaming server (defered stop body)' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						body = ::Async::HTTP::Body::Writable.new
						
						Async do |task|
							task.defer_stop do
								10.times do
									body.write("Hello, World!\n")
									task.sleep(0.1)
								end
							end
						rescue => error
							events.enqueue(error)
						ensure
							body.close(error)
						end
						
						::Protocol::HTTP::Response[200, {}, body]
					end
				end
				
				it "should stop gracefully" do
					response = client.get("/")
					expect(response).to be(:success?)
					
					@server_task.stop
					
					expect(response.read).to be == "Hello, World!\n" * 10
				end
			end
			
			with 'a streaming server' do
				let(:app) do
					::Protocol::HTTP::Middleware.for do |request|
						body = ::Async::HTTP::Body::Writable.new
						
						Async do |task|
							10.times do
								body.write("Hello, World!\n")
								task.sleep(0.1)
							end
						rescue => error
							events.enqueue(error)
						ensure
							body.close(error)
						end
						
						::Protocol::HTTP::Response[200, {}, body]
					end
				end
				
				it "should stop gracefully" do
					response = client.get("/")
					expect(response).to be(:success?)
					
					@server_task.stop
					
					inform(response.read)
				end
			end
		end
	end
end
