# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2023, by Samuel Williams.

require_relative '../../server_context'
require 'async/http/protocol/http11'

RSpec.describe Async::HTTP::Protocol::HTTP11, timeout: 30 do
	include_context Async::HTTP::Server
	
	let(:server) do
		Async::HTTP::Server.for(@bound_endpoint) do |request|
			Protocol::HTTP::Response[200, {}, [request.path]]
		end
	end
	
	around do |example|
		current = Console.logger.level
		Console.logger.fatal!
	
		example.run
	ensure
		Console.logger.level = current
	end
	
	it "doesn't desync responses" do
		tasks = []
		task = Async::Task.current
		
		backtraces = []
		
		100.times do
			tasks << task.async{
				loop do
					response = client.get('/a')
					expect(response.read).to be == "/a"
				rescue Exception => exception
					backtraces << exception&.backtrace
					raise
				ensure
					response&.close
				end
			}
		end
		
		100.times do
			tasks << task.async{
				loop do
					response = client.get('/b')
					expect(response.read).to be == "/b"
				rescue Exception => exception
					backtraces << exception&.backtrace
					raise
				ensure
					response&.close
				end
			}
		end
		
		tasks.each do |child|
			task.sleep 0.01
			child.stop
		end
		
		puts "Backtraces"
		pp backtraces.sort.uniq
	end
end
