# Mocking

This guide explains how to modify `Async::HTTP::Client` for mocking responses in tests.

## Mocking HTTP Responses

The mocking feature of `Async::HTTP` uses a real server running in a separate task, and routes all requests to it. This allows you to intercept requests and return custom responses, but still use the real HTTP client.

In order to enable this feature, you must create an instance of {ruby Async::HTTP::Mock::Endpoint} which will handle the requests.

~~~ ruby
require 'async/http'
require 'async/http/mock'

mock_endpoint = Async::HTTP::Mock::Endpoint.new

Sync do
	# Start a background server:
	server_task = Async(transient: true) do
		mock_endpoint.run do |request|
			# Respond to the request:
			::Protocol::HTTP::Response[200, {}, ["Hello, World"]]
		end
	end
	
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
	mocked_endpoint = mock_endpoint.wrap(endpoint)
	client = Async::HTTP::Client.new(mocked_endpoint)
	
	response = client.get("/")
	puts response.read
	# => "Hello, World"
end
~~~

## Transparent Mocking

Using your test framework's mocking capabilities, you can easily replace the `Async::HTTP::Client#new` with a method that returns a client with a mocked endpoint.

### Sus Integration

~~~ ruby
require 'async/http'
require 'async/http/mock'
require 'sus/fixtures/async/reactor_context'

include Sus::Fixtures::Async::ReactorContext

let(:mock_endpoint) {Async::HTTP::Mock::Endpoint.new}

def before
	super
	
	# Mock the HTTP client:
	mock(Async::HTTP::Client) do |mock|
		mock.wrap(:new) do |original, endpoint|
			original.call(mock_endpoint.wrap(endpoint))
		end
	end
	
	# Run the mock server:
	Async(transient: true) do
		mock_endpoint.run do |request|
			::Protocol::HTTP::Response[200, {}, ["Hello, World"]]
		end
	end
end

it "should perform a web request" do
	client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse("https://www.google.com"))
	response = client.get("/")
	# The response is mocked:
	expect(response.read).to be == "Hello, World"
end
~~~
