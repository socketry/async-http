require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

task :server do
	require_relative 'lib/async/http/server'
	require 'async/reactor'
	
	app = lambda do |env|
		[200, {}, ["Hello World"]]
	end
	
	server = Async::HTTP::Server.new([[:tcp, '0.0.0.0', 9293]], app)
	
	Async::Reactor.run do
		server.run
	end
end
