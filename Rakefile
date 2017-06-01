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
	
	pids.each do |pid|
		Process.wait pid
	end
end
