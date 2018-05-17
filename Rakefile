require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

require 'async/http/protocol'
require 'async/io/host_endpoint'

PROTOCOL = Async::HTTP::Protocol::HTTP1

task :debug do
	require 'async/logger'
	
	Async.logger.level = Logger::DEBUG
end

task :server do
	require 'async/reactor'
	require 'async/container/forked'
	require 'async/http/server'
	
	server = Async::HTTP::Server.new(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), PROTOCOL) do |request, peer, address|
		return Async::HTTP::Response[200, {'content-type' => 'text/plain'}, ["Hello World"]]
	end
	
	container = Async::Container::Forked.new(concurrency: 1) do
		#GC.disable
		
		server.run
	end
	
	container.wait
end

task :benchmark do
	sh 'wrk -t 8 -c 8 -d 2 http://127.0.0.1:9294'
end

task :client do
	require 'async/reactor'
	require 'async/http/client'
	
	client = Async::HTTP::Client.new(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), PROTOCOL)
	
	Async::Reactor.run do
		response = client.get("/")
		
		puts response.inspect
		
		client.close
	end
end

task :wrk do
	require 'async/reactor'
	require 'async/http/server'
	
	app = lambda do |env|
		[200, {}, ["Hello World"]]
	end
	
	server = Async::HTTP::Server.new(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), app)
	
	process_count = Etc.nprocessors
	
	pids = process_count.times.collect do
		fork do
			Async::Reactor.run do
				server.run
			end
		end
	end

	url = "http://127.0.0.1:9294/"
	
	connections = process_count
	system("wrk", "-c", connections.to_s, "-d", "2", "-t", connections.to_s, url)

	pids.each do |pid|
		Process.kill(:KILL, pid)
		Process.wait pid
	end
end
