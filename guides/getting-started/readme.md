# Getting Started

This guide explains how to make HTTP requests and serve HTTP responses with `Async::HTTP`.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-http
~~~

## Core Concepts

`Async::HTTP` provides several interfaces for different kinds of HTTP applications:

- ruby:`Async::HTTP::Internet` makes requests to arbitrary hosts and manages a client for each remote endpoint.
- ruby:`Async::HTTP::Client` manages persistent connections to a specific endpoint.
- ruby:`Async::HTTP::Server` accepts connections and dispatches requests to an HTTP application.
- ruby:`Async::HTTP::Endpoint` describes how a client connects or a server listens, including the URL, protocol, and TLS configuration.
- [`protocol-http`](https://github.com/socketry/protocol-http) provides the shared request, response, header, and body interfaces.

Use `Internet` for general-purpose requests to different hosts. Use `Client` when your application repeatedly communicates with one endpoint or needs endpoint-specific configuration.

## Making a Request

The shared ruby:`Async::HTTP::Internet` instance provides a convenient starting point. Run asynchronous HTTP operations inside `Sync`, which creates or reuses the event loop while returning the block result directly:

~~~ ruby
require "async/http/internet/instance"

Sync do
	Async::HTTP::Internet.get("https://httpbin.org/get") do |response|
		puts "Status: #{response.status}"
		puts response.read
	end
end
~~~

Passing a block automatically closes the response when the block exits, including when an exception is raised. Responses are streamed, so callers that do not use the block form must close the response explicitly.

~~~ ruby
require "async/http/internet/instance"

Sync do
	response = Async::HTTP::Internet.get("https://httpbin.org/get")
	puts response.read
ensure
	response&.close
end
~~~

Convenience methods are provided for `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`, `OPTIONS`, `TRACE`, `PATCH`, and `QUERY` requests.

### Connection Persistence

`Internet` creates a ruby:`Async::HTTP::Client` for each remote endpoint and reuses its persistent connections. The underlying async pools are bound to the event loop and are closed when that event loop exits.

An explicitly created `Internet` can also be closed early when an application wants to release all cached clients before the event loop exits:

~~~ ruby
require "async/http/internet"

Sync do
	internet = Async::HTTP::Internet.new

	internet.get("https://example.com") do |response|
		puts response.status
	end
ensure
	internet&.close
end
~~~

## Working with Responses

A response contains a status, headers, and a streaming body. Check the status before processing content, and use header names in lower case:

~~~ ruby
require "async/http/internet/instance"

Sync do
	Async::HTTP::Internet.get("https://httpbin.org/json") do |response|
		if response.success?
			puts response.headers["content-type"]
			puts response.read
		else
			warn "Request failed with status #{response.status}."
		end
	end
end
~~~

For larger responses, process the body incrementally rather than reading it into one string. See the `protocol-http` message body documentation for the complete body interface.

### Downloading a File

Use `response.save` to stream a response directly to a file:

~~~ ruby
require "async/http/internet/instance"

Sync do
	Async::HTTP::Internet.get("https://example.com/archive.zip") do |response|
		raise "Download failed with status #{response.status}." unless response.success?
		
		response.save("archive.zip")
	end
end
~~~

## Posting JSON

Pass headers and a body after the request target. The body may be a string or a compatible `protocol-http` body object.

~~~ ruby
require "async/http/internet/instance"
require "json"

data = {life: 42}
headers = [
	["accept", "application/json"],
	["content-type", "application/json"],
]

Sync do
	Async::HTTP::Internet.post("https://httpbin.org/anything", headers, JSON.dump(data)) do |response|
		raise "Request failed with status #{response.status}." unless response.success?
		
		puts JSON.pretty_generate(JSON.parse(response.read))
	end
end
~~~

For resource-oriented HTTP APIs, consider using [`async-rest`](https://github.com/socketry/async-rest), which builds on `Async::HTTP`.

## Applying a Timeout

Networks can stall indefinitely, so impose a timeout around operations that must complete within a fixed duration:

~~~ ruby
require "async/http/internet/instance"

Sync do |task|
	task.with_timeout(2) do
		Async::HTTP::Internet.get("https://httpbin.org/delay/10") do |response|
			puts response.read
		end
	end
rescue Async::TimeoutError
	warn "The request timed out."
end
~~~

The response block still closes the response if the timeout interrupts the request while its body is being processed.

## Making a Server

ruby:`Async::HTTP::Server` accepts an application that maps each request to a ruby:`Protocol::HTTP::Response`. The following example starts a local server, makes one request, and then releases both client and server resources:

~~~ ruby
require "async/http"

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")
server = Async::HTTP::Server.for(endpoint) do |request|
	Protocol::HTTP::Response[200, {"content-type" => "text/plain"}, ["Hello World"]]
end

Sync do
	server_task = server.run
	
	Async::HTTP::Client.open(endpoint) do |client|
		response = client.get("/")
		puts response.read
	ensure
		response&.close
	end
ensure
	server_task&.stop
end
~~~

Use Falcon when you need to host a Rack application or deploy an HTTP server in production. Use `Async::HTTP::Server` directly when building a protocol-level server or embedding HTTP handling into another asynchronous application.
