require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

task :server do
	require_relative 'lib/async/http/server'
	require 'async/reactor'
	
	require 'etc'
	
	app = lambda do |env|
		[200, {}, ["Hello World"]]
	end
	
	server = Async::HTTP::Server.new([
		Async::IO::Address.tcp('127.0.0.1', 9294, reuse_port: true)
	], app)
	
	process_count = Etc.nprocessors
	
	pids = process_count.times.collect do
		fork do
			Async::Reactor.run do
				server.run
			end
		end
	end
	
	url = "http://127.0.0.1:9294/"
	system("ab", "-t", "2", "-c", process_count.to_s, url)
	system("wrk", "-c", process_count.to_s, "-d", "2", "-t", process_count.to_s, url)
	
	pids.each do |pid|
		Process.kill(:KILL, pid)
		Process.wait pid
	end
end
