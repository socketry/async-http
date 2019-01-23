
task :http1 do
	require 'async/http/protocol'
	require 'async/http/url_endpoint'
	require 'async/io/host_endpoint'

	@protocol = Async::HTTP::Protocol::HTTP1
end

task :debug do
	require 'async/logger'
	
	Async.logger.level = Logger::DEBUG
end

task :google do
	require 'async'
	require 'pry'
	
	Async.run do
		endpoint = Async::HTTP::URLEndpoint.parse("https://www.google.com")
		peer = endpoint.connect
		stream = Async::IO::Stream.new(peer)
		
		framer = ::HTTP::Protocol::HTTP2::Framer.new(stream)
		client = ::HTTP::Protocol::HTTP2::Client.new(framer)
		
		client.send_connection_preface
		
		stream = ::HTTP::Protocol::HTTP2::Stream.new(client)
		
		client.read_frame
		client.read_frame
		
		stream.send_headers(nil, [[':method', 'GET'], [':authority', 'www.google.com'], [':path', '/']], ::HTTP::Protocol::HTTP2::END_STREAM)
		
		binding.pry
	end
end

task :server do
	require 'async/reactor'
	require 'async/container/forked'
	require 'async/http/server'
	
	server = Async::HTTP::Server.for(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), @protocol) do |request|
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
	
	client = Async::HTTP::Client.new(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), @protocol)
	
	Async::Reactor.run do
		response = client.get("/")
		
		puts response.inspect
		
		client.close
	end
end

task :wrk do
	require 'async/reactor'
	require 'async/http/server'
	require 'async/container/forked'

	server = Async::HTTP::Server.for(Async::IO::Endpoint.tcp('127.0.0.1', 9294, reuse_port: true), @protocol) do |request|
		return Async::HTTP::Response[200, {'content-type' => 'text/plain'}, ["Hello World"]]
	end

	concurrency = 1
	
	container = Async::Container::Forked.new(concurrency: concurrency) do
		server.run
	end

	url = "http://127.0.0.1:9294/"
	
	5.times do
		system("wrk", "-c", concurrency.to_s, "-d", "10", "-t", concurrency.to_s, url)
	end

	container.stop
end
