
namespace :h2spec do
	task :build do
		# Fetch the code:
		sh "go get github.com/spf13/cobra"
		sh "go get github.com/summerwind/h2spec"
		
		# This builds `h2spec` into the current directory
		sh "go build ~/go/src/github.com/summerwind/h2spec/cmd/h2spec/h2spec.go"
	end
	
	task :server do
		require 'async/reactor'
		require 'async/container'
		require 'async/http/server'
		require 'async/io/host_endpoint'
		
		endpoint = Async::IO::Endpoint.tcp('127.0.0.1', 7272)
		
		server = Async::HTTP::Server.for(endpoint, Async::HTTP::Protocol::HTTP2, "https") do |request|
			Protocol::HTTP::Response[200, {'content-type' => 'text/plain'}, ["Hello World"]]
		end
		
		@container = Async::Container.new
		
		Async.logger.info(self){"Starting server..."}
		@container.run(count: 1) do
			server.run
		end
	end
	
	task :test => :server do
		begin
			if test = ENV['TEST']
				sh("./h2spec", test, "-p", "7272")
			else
				sh("./h2spec", "-p", "7272")
			end
		ensure
			@container.stop(false)
		end
	end
	
	task :all => [:build, :test]
end
