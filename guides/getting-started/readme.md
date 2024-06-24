# Getting Started

This guide explains how to get started with `Async::HTTP`.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-http
~~~

## Core Concepts

- {ruby Async::HTTP::Client} is the main class for making HTTP requests.
- {ruby Async::HTTP::Internet} provides a simple interface for making requests to any server "on the internet".
- {ruby Async::HTTP::Server} is the main class for handling HTTP requests.
- {ruby Async::HTTP::Endpoint} can parse HTTP URLs in order to create a client or server.
- [`protocol-http`](https://github.com/socketry/protocol-http) provides the abstract HTTP protocol interfaces.

## Usage

### Making a Request

To make a request, use {ruby Async::HTTP::Internet} and call the appropriate method:

~~~ ruby
require 'async/http/internet/instance'

Sync do
	Async::HTTP::Internet.get("https://httpbin.org/get") do |response|
		puts response.read
	end
end
~~~

The following methods are supported:

~~~ ruby
Async::HTTP::Internet.methods(false)
# => [:patch, :options, :connect, :post, :get, :delete, :head, :trace, :put]
~~~

Using a block will automatically close the response when the block completes. If you want to keep the response open, you can manage it manually:

~~~ ruby
require 'async/http/internet/instance'

Sync do
	response = Async::HTTP::Internet.get("https://httpbin.org/get")
	puts response.read
ensure
	response&.close
end
~~~

As responses are streamed, you must ensure it is closed when you are finished with it.

#### Persistence

By default, {ruby Async::HTTP::Internet} will create a {ruby Async::HTTP::Client} for each remote host you communicate with, and will keep those connections open for as long as possible. This is useful for reducing the latency of subsequent requests to the same host. When you exit the event loop, the connections will be closed automatically.

### Downloading a File

~~~ ruby
require 'async/http/internet/instance'

Sync do
	# Issue a GET request to Google:
	response = Async::HTTP::Internet.get("https://www.google.com/search?q=kittens")
	
	# Save the response body to a local file:
	response.save("/tmp/search.html")
ensure
	response&.close
end
~~~

### Posting Data

To post data, use the `post` method:

~~~ ruby
require 'async/http/internet/instance'

data = {'life' => 42}

Sync do
	# Prepare the request:
	headers = [['accept', 'application/json']]
	body = JSON.dump(data)
	
	# Issues a POST request:
	response = Async::HTTP::Internet.post("https://httpbin.org/anything", headers, body)
	
	# Save the response body to a local file:
	pp JSON.parse(response.read)
ensure
	response&.close
end
~~~

For more complex scenarios, including HTTP APIs, consider using [async-rest](https://github.com/socketry/async-rest) instead.

### Timeouts

To set a timeout for a request, use the `Task#with_timeout` method:

~~~ ruby
require 'async/http/internet/instance'

Sync do |task|
	# Request will timeout after 2 seconds
	task.with_timeout(2) do
		response = Async::HTTP::Internet.get "https://httpbin.org/delay/10"
	ensure
		response&.close
	end
rescue Async::TimeoutError
	puts "The request timed out"
end
~~~

### Making a Server

To create a server, use an instance of {ruby Async::HTTP::Server}:

~~~ ruby
require 'async/http'

endpoint = Async::HTTP::Endpoint.parse('http://localhost:9292')

Sync do |task|
	Async(transient: true) do
		server = Async::HTTP::Server.for(endpoint) do |request|
			::Protocol::HTTP::Response[200, {}, ["Hello World"]]
		end
		
		server.run
	end
	
	client = Async::HTTP::Client.new(endpoint)
	response = client.get("/")
	puts response.read
ensure
	response&.close
end
~~~
