# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

def build
	# Fetch the code:
	system "go get github.com/spf13/cobra"
	system "go get github.com/summerwind/h2spec"
	
	# This builds `h2spec` into the current directory
	system "go build ~/go/src/github.com/summerwind/h2spec/cmd/h2spec/h2spec.go"
end

def test
	server do
		system("./h2spec", "-p", "7272")
	end
end

private

def server
	require "async"
	require "async/container"
	require "async/http/server"
	require "io/endpoint/host_endpoint"
	
	endpoint = IO::Endpoint.tcp("127.0.0.1", 7272)
	
	container = Async::Container.new
	
	Console.info(self){"Starting server..."}
	
	container.run(count: 1) do
		server = Async::HTTP::Server.for(endpoint, protocol: Async::HTTP::Protocol::HTTP2, scheme: "https") do |request|
			Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello World"]]
		end
		
		Async do
			server.run
		end
	end
	
	yield if block_given?
ensure
	container&.stop
end
