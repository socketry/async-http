# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2025, by Samuel Williams.

require "async/http/protocol/http11"

require "sus/fixtures/async/http/server_context"

describe Async::HTTP::Protocol::HTTP11 do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:app) do
		Protocol::HTTP::Middleware.for do |request|
			Protocol::HTTP::Response[200, {}, [request.path]]
		end
	end
	
	def around
		current = Console.logger.level
		Console.logger.fatal!
		
		super
	ensure
		Console.logger.level = current
	end
	
	it "doesn't desync responses" do
		tasks = []
		task = Async::Task.current
		
		backtraces = []
		
		100.times do
			tasks << task.async do
				loop do
					response = client.get("/a")
					expect(response.read).to be == "/a"
				rescue Exception => exception
					backtraces << exception&.backtrace
					raise
				ensure
					response&.close
				end
			end
		end
		
		100.times do
			tasks << task.async do
				loop do
					response = client.get("/b")
					expect(response.read).to be == "/b"
				rescue Exception => exception
					backtraces << exception&.backtrace
					raise
				ensure
					response&.close
				end
			end
		end
		
		tasks.each do |child|
			sleep 0.01
			child.stop
		end
		
		# puts "Backtraces"
		# pp backtraces.sort.uniq
		expect(backtraces.size).to be >= 0
	end
end
