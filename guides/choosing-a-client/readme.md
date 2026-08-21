# Choosing a Client

This guide explains how to choose between ruby:`Async::HTTP::Internet`, ruby:`Async::HTTP::Client`, and direct ruby:`Protocol::HTTP::Request` handling. It also explains how libraries should expose their HTTP dependency.

All three approaches use the same request and response model. The important differences are how destinations are selected, where connection settings are applied, and who owns the client life cycle.

## Quick Decision

| Situation | Interface | Why |
| --- | --- | --- |
| Requests may target different origins and the defaults are suitable. | Shared ruby:`Async::HTTP::Internet` | Selects and reuses a client for each origin automatically. |
| Requests may target different origins, but need common client options or explicit ownership. | Explicit ruby:`Async::HTTP::Internet` | Applies the same options to each managed client and can be injected or closed early. |
| Requests repeatedly target one configured origin. | ruby:`Async::HTTP::Client` | Exposes the endpoint, protocol, retry, and connection-pool configuration directly. |
| A request is constructed separately or passed through middleware. | ruby:`Protocol::HTTP::Request` with `call` | Preserves the complete HTTP message across integration boundaries. |

Application code can start with the shared `Internet` interface unless it has a specific ownership or configuration requirement. Library code should accept an explicit HTTP dependency.

## Shared Internet for General Requests

The shared `Internet` interface is the simplest choice for requests to arbitrary URLs. It maintains one client for each origin and reuses persistent connections:

~~~ ruby
require "async/http/internet/instance"

urls = [
	"https://www.ruby-lang.org/en/",
	"https://example.com/",
]

Sync do
	urls.each do |url|
		Async::HTTP::Internet.get(url) do |response|
			puts "#{url}: #{response.status}"
		end
	end
end
~~~

The class-level interface uses a thread-local `Internet` instance. Its connection pools are bound to the event loop and close when that event loop exits. The response block closes each response after it is processed.

Use the shared interface when:

- The application requests URLs from multiple or dynamically selected origins.
- Default retry and connection-pool settings are suitable.
- The client does not need to be injected as an application dependency.

## Explicit Internet for Shared Configuration

An explicit `Internet` provides the same per-origin client selection while making ownership and client options visible. Options are passed to every client it creates; for example, `limit` applies independently to the pool for each origin:

~~~ ruby
require "async/http/internet"

Sync do
	internet = Async::HTTP::Internet.new(retries: 1, limit: 4)
	
	begin
		internet.get("https://www.ruby-lang.org/en/") do |response|
			puts response.status
		end
	ensure
		internet.close
	end
end
~~~

Use an explicit `Internet` when:

- Several origins should share the same retry or pool settings.
- The client should be injected into another object or replaced during testing.
- Connections should be released before the event loop exits.

## Client for One Endpoint

A `Client` targets one ruby:`Async::HTTP::Endpoint`. Use it when a remote service is a stable part of the application architecture and needs its own protocol, TLS, retry, or pool configuration:

~~~ ruby
require "async/http"

endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org")

Sync do
	Async::HTTP::Client.open(endpoint, retries: 1, limit: 4) do |client|
		response = client.get("/status/200")
		
		begin
			puts response.status
		ensure
			response.close
		end
	end
end
~~~

Client convenience methods accept a path rather than a complete URL. They return a response that the caller must close. `Client.open` closes the client and its connection pool when the block exits.

Reuse a client for repeated requests rather than creating one per request; otherwise the application cannot benefit from persistent connections.

## Building a Library That Makes HTTP Requests

A library should generally accept its HTTP client as an explicit dependency. This lets the application configure connection limits, retries, proxies, instrumentation, and test doubles without the library creating hidden global state:

~~~ ruby
require "async/http"

class StatusService
	def initialize(client)
		@client = client
	end
	
	def healthy?
		response = @client.get("/status/200")
		response.status == 200
	ensure
		response&.close
	end
end

endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org")

Sync do
	Async::HTTP::Client.open(endpoint) do |client|
		puts StatusService.new(client).healthy?
	end
end
~~~

The library does not close an injected client because the caller owns it and may share it with other components. If the library also provides an `open` convenience method that constructs a client, that method should close the client it creates when its block exits.

Define the accepted interface precisely. A ruby:`Async::HTTP::Client` is bound to one endpoint and its convenience methods accept relative paths, while ruby:`Async::HTTP::Internet` selects an endpoint from a complete URL. They should not be treated as interchangeable merely because both provide methods such as `get`. If the library constructs ruby:`Protocol::HTTP::Request` objects and only calls `call`, it can accept a `Protocol::HTTP` middleware delegate instead of requiring a concrete client.

For higher-level library APIs, consider these established abstractions:

- [`async-rest`](https://socketry.github.io/async-rest/guides/getting-started/) provides resource and representation abstractions for modeling a remote HTTP API. ruby:`Async::REST::Resource` accepts a `Protocol::HTTP` middleware delegate, while its `open` method is an ownership convenience that creates and closes a ruby:`Async::HTTP::Client`.
- [`async-http-faraday`](https://socketry.github.io/async-http-faraday/guides/getting-started/) lets a library use Faraday as its public HTTP abstraction while applications select Async::HTTP as the adapter. This is useful when compatibility with the Faraday ecosystem matters; a new Async-native interface can usually accept a ruby:`Async::HTTP::Client` directly.

If a library uses Faraday, accept a configured `Faraday::Connection` rather than changing `Faraday.default_adapter` globally. The application can then select the Async::HTTP adapter for that connection:

~~~ ruby
require "async/http/faraday"

class StatusService
	def initialize(connection)
		@connection = connection
	end
	
	def healthy?
		@connection.get("/status/200").success?
	end
end

connection = Faraday.new("https://httpbin.org") do |builder|
	builder.adapter :async_http
end

puts StatusService.new(connection).healthy?
~~~

## Prepared Requests and Middleware

A ruby:`Protocol::HTTP::Request` is not another connection-management strategy. It is the complete HTTP message accepted by ruby:`Async::HTTP::Client#call` and by `Protocol::HTTP` middleware:

~~~ ruby
require "async/http"

endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org")

Sync do
	Async::HTTP::Client.open(endpoint) do |client|
		request = Protocol::HTTP::Request[
			"POST",
			"/anything",
			{"content-type" => "application/json"},
			'{"task":"refresh"}',
		]
		response = client.call(request)
		
		begin
			puts response.status
		ensure
			response.close
		end
	end
end
~~~

Construct requests directly when another component produces the message, when using middleware, or when sending a custom HTTP method without a convenience method. The client still determines the endpoint and manages the connections.

For direct, in-process middleware tests, see the [Testing guide](../testing/). For the complete message interface, see the [`protocol-http` Getting Started guide](https://socketry.github.io/protocol-http/guides/getting-started/).

## Recommendation

Use the narrowest interface that matches the destination scope:

1. Start with the shared `Internet` interface for general URL-based requests.
2. Use an explicit `Internet` when several origins need common configuration or explicit ownership.
3. Use a `Client` when one endpoint is a named application dependency.
4. Construct requests directly when integrating with middleware or another component that already works with HTTP messages.
5. When building a library, accept and document the narrowest HTTP interface it needs; leave transport configuration and injected-client ownership to the application.
