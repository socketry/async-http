# Testing

This guide explains how to test `Async::HTTP` clients and servers without depending on external HTTP services.

Real network services make tests slower and less deterministic. Prefer one of these approaches:

- Use `sus-fixtures-async-http` to run an application with a managed local server and client.
- Use ruby:`Async::HTTP::Mock::Endpoint` when testing a client that expects to connect to a particular remote endpoint.
- Use a small fake client when the HTTP protocol behavior itself is not under test.

## Testing an HTTP Application

The `ServerContext` fixture manages an ephemeral listening endpoint, server task, and connected client. Add the fixture to your test dependencies:

~~~ bash
$ bundle add sus --group test
$ bundle add sus-fixtures-async-http --group test
~~~

Define the application under test and make requests through the provided `client`:

~~~ ruby
require "sus/fixtures/async/http"

describe "My HTTP application" do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:app) do
		Protocol::HTTP::Middleware.for do |request|
			case request.path
			when "/health"
				Protocol::HTTP::Response[
					200,
					{"content-type" => "application/json"},
					['{"status":"ok"}'],
				]
			else
				Protocol::HTTP::Response[404, {}, ["Not Found"]]
			end
		end
	end
	
	it "serves the health endpoint" do
		response = client.get("/health")
		
		expect(response).to be(:success?)
		expect(response.headers["content-type"]).to be == "application/json"
		expect(response.read).to be == '{"status":"ok"}'
	ensure
		response&.close
	end
	
	it "returns not found for unknown paths" do
		response = client.get("/missing")
		expect(response.status).to be == 404
	ensure
		response&.close
	end
end
~~~

The fixture closes the client, stops the server, and releases the bound endpoint after each test. Override `app`, `url`, `protocol`, `endpoint_options`, or `retries` to configure a scenario.

### Testing HTTP/2

Override `protocol` when behavior must be verified with a specific HTTP version:

~~~ ruby
describe "My HTTP/2 application" do
	include Sus::Fixtures::Async::HTTP::ServerContext
	
	let(:protocol) {Async::HTTP::Protocol::HTTP2}
	
	it "responds using HTTP/2" do
		response = client.get("/")
		expect(response.version).to be == "HTTP/2"
	ensure
		response&.close
	end
end
~~~

Test normal behavior without forcing a protocol unless the distinction is relevant to the feature under test.

## Testing a Client with a Mock Endpoint

ruby:`Async::HTTP::Mock::Endpoint` connects the real client and server protocol implementations through a local socket pair. It does not open a network port, but requests still exercise serialization, connection handling, and response bodies.

Use ruby:`Async::HTTP::Mock::Endpoint#wrap` to preserve the scheme and authority expected by the client:

~~~ ruby
require "async/http"
require "async/http/mock"
require "sus/fixtures/async/reactor_context"

describe "A remote service client" do
	include Sus::Fixtures::Async::ReactorContext
	
	it "handles a successful response" do
		mock_endpoint = Async::HTTP::Mock::Endpoint.new
		server_task = Async do
			mock_endpoint.run do |request|
				Protocol::HTTP::Response[200, {}, ["Authority: #{request.authority}"]]
			end
		end
		
		remote_endpoint = Async::HTTP::Endpoint.parse("https://api.example.com")
		client = Async::HTTP::Client.new(mock_endpoint.wrap(remote_endpoint))
		response = client.get("/status")
		
		expect(response.read).to be == "Authority: api.example.com"
	ensure
		response&.close
		client&.close
		server_task&.stop
	end
end
~~~

Return different statuses, headers, bodies, delays, or malformed behavior from the mock server to exercise client error handling.

## Transparently Replacing Client Endpoints

Some applications construct ruby:`Async::HTTP::Client` internally. A test can wrap the constructor so those clients connect to a mock endpoint while retaining the original endpoint metadata and client options:

~~~ ruby
require "async/http"
require "async/http/mock"
require "sus/fixtures/async/reactor_context"

describe "A client created by application code" do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:mock_endpoint) {Async::HTTP::Mock::Endpoint.new}
	
	def before
		super
		
		replacement_endpoint = mock_endpoint
		mock(Async::HTTP::Client) do |wrapper|
			wrapper.wrap(:new) do |original, endpoint, **options|
				original.call(replacement_endpoint.wrap(endpoint), **options)
			end
		end
		
		@server_task = Async do
			mock_endpoint.run do |request|
				Protocol::HTTP::Response[200, {}, ["Hello, World"]]
			end
		end
	end
	
	def after(error = nil)
		@server_task&.stop
		super
	end
	
	it "routes the request through the mock endpoint" do
		endpoint = Async::HTTP::Endpoint.parse("https://api.example.com")
		client = Async::HTTP::Client.new(endpoint, retries: 1)
		response = client.get("/")
		
		expect(response.read).to be == "Hello, World"
	ensure
		response&.close
		client&.close
	end
end
~~~

Always accept and forward `**options` when wrapping the constructor so the test does not silently change client configuration.
