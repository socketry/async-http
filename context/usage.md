## Overview

As per official documentation, the `async-http` gem is an asynchronous client and server implementation of HTTP/1.0, HTTP/1.1 and HTTP/2 including TLS. It offers support for streaming requests and responses. This gem is built on top of `async` and `async-io`

The gem requires Ruby >= 3.1.
## Basic Syntax

### `Async::HTTP::Endpoint`

The `Async::HTTP::Endpoint` class can parse HTTP URLs and store information about them. This class is one of the building blocks for both clients and servers in this gem.

#### Generic Usage

```ruby
endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")

client = Async::HTTP::Client.new(endpoint) # client using the Endpoint

server = Async::HTTP::Server.for(endpoint) do |request|
	::Protocol::HTTP::Response[200, {}, ["Hello World"]]
end # server using the Endpoint
```

It must be mentioned that a user can pass `tls_context:` or `proxy:` when parsing the endpoint if you need custom certificates or an HTTP connection proxy.

```ruby
proxy  = Async::HTTP::Endpoint.parse("http://corp-proxy.local:3128")  # Proxy must be an Async::HTTP::Endpoint instance.
target = Async::HTTP::Endpoint.parse("https://api.example.com", proxy: proxy)
Async::HTTP::Client.new(target)
...
```

### `Async::HTTP::Client` 

The `Async::HTTP::Client` is the main class for making HTTP requests. It uses the `Async::HTTP::Endpoint` class. In order for instances of the above class to run asynchronous requests, they must be wrapped in blocks that ensure the existence of a scheduler, and therefore of an event loop.

The following methods are supported: `[:patch, :options, :connect, :post, :get, :delete, :head, :trace, :put]`.

The `Async::HTTP::Client` instance's methods can be used directly to process requests.
#### Making a GET Request

```ruby
require 'async'
require 'async/http/client'
require 'async/http/endpoint'

Async do
    endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org/get", protocol: Async::HTTP::Protocol::HTTP10)
    client = Async::HTTP::Client.new(endpoint)
    response = client.get(endpoint.path)
    puts response, response.read
end
```

#### Making a POST Request

```ruby
require 'async'
require 'async/http/client'
require 'async/http/endpoint'

data = {'life' => 42}

Sync do
	# Prepares an endpoint:
	endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org/anything", protocol: Async::HTTP::Protocol::HTTP10)
	# Prepares the client
	client = Async::HTTP::Client.new(endpoint)

	# Prepare the request:
	headers = [['accept', 'application/json']]
	body = JSON.dump(data)
	
	# Issues a POST request:
	response = client.post(endpoint.path, headers, body)
	
	# Save the response body to a local file:
	pp JSON.parse(response.read)
ensure
	client&.close
end
```
	
#### Making a GET Request using `call` and `Protocol::HTTP::Request`

```ruby
require 'async'
require 'async/http/client'
require 'async/http/protocol/request'
require 'async/http/endpoint'

Async do |task|
    endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")

    client = Async::HTTP::Client.new(endpoint)

    headers = {
         "accept" => "text/html",
    }

    request = Protocol::HTTP::Request.new(client.scheme, "www.google.com", "GET", "/search?q=cats", headers)

    puts "Sending request..."
    response = client.call(request)

    puts "Reading response status=#{response.status}..."

    if body = response.body
        while chunk = body.read
            puts chunk.size
        end
    end

    response.close

    puts "Finish reading response."
ensure
	client.close
end
```

### `Async::HTTP::Internet`

The `Async::HTTP::Internet` class provides a simple interface for making requests to any server that is "on the internet". In order for instances of the above class to run asynchronous requests, they must be wrapped in blocks that ensure the existence of a scheduler, and therefore of an event loop.

By default, the `Async::HTTP::Internet` will create a class of `Async::HTTP::Client` for each remote host you communicate with, and will keep those connections open for as long as possible. This is useful for reducing the latency of subsequent requests to the same host. Once the event loop is exit, the connections will be closed automatically.

The following methods are supported: `[:patch, :options, :connect, :post, :get, :delete, :head, :trace, :put]`.

#### Making a GET Request

```ruby
require 'async'
require 'async/http/internet/instance'

Sync do
	Async::HTTP::Internet.get("https://httpbin.org/get") do |response|
		puts response.read
	end
end
```
require 'async'
require 'async/http/internet/instance'

Sync do
	Async::HTTP::Internet.get("https://httpbin.org/get") do |response|
		puts response.read
	end
end
The above example also uses a block, which automatically closes the response when the block completes. If users want to keep the response open, they should manage it manually. Given that responses are streamed, users must ensure they get closed once they are no longer needed.

```ruby
require 'async'
require 'async/http/internet/instance'

Sync do
	response = Async::HTTP::Internet.get("https://httpbin.org/get")
	puts response.read
ensure
	response&.close
end
```
#### Making a POST Request

```ruby
require 'async'
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
```
#### Set Timeout for any Request

In order to achieve this the user must use the `async` `Async::Task#with_timeout` method.

```ruby
require 'async'
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
```

### `Async::HTTP::Server`

The `Async::HTTP::Server` is the main class for handling HTTP requests. In order for instances of the above class to process asynchronous operations, they must be wrapped in blocks that ensure the existence of a scheduler, and therefore of an event loop.

```ruby
require 'async'
require "async/http"

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")

Sync do
  Async(transient: true) do
    server = Async::HTTP::Server.for(endpoint) do |request|
      case request.path
      when "/foo"
        Protocol::HTTP::Response[200, {}, ["Hello Foo"]]
      when "/bar"
        Protocol::HTTP::Response[200, {}, ["Hello Bar"]]
      else
        Protocol::HTTP::Response[404, {}, ["Not Found"]]
      end
    end

    server.run       # runs in its own fiber
  end

  client = Async::HTTP::Client.new(endpoint)

  ["/foo", "/bar", "/baz"].each do |path|
    response = client.get(path)
    puts "#{path} → #{response.status} : #{response.read}"
  ensure
    response&.close
  end
  # foo returns a 200
  # bar returns a 200
  # baz returns a 404
ed

```

## Best Practices

1. Keep a single `Async::HTTP::Internet` instance (or a `Client` per authority) for the life of the reactor. Connection pooling & keep-alive happen automatically and this way the user saves a round-trip after the first request.
2. The user must ensure the closing of the response, or use the block form.
3. Let the default ALPN negotiate when picking the right wire-protocol. The user can also pass `Async::HTTP::Protocol::HTTP2` when they know that the server supports it.
4. For uploads, do not load the whole source file in-memory and then send it over to the server. The user should write to `Protocol::HTTP::Body::Writable` as they read the source file. In addition, even if some examples are using the old `async-io` gem, the new direction is to use the `io/stream` which is light(er)weight and compatible with everything.

```ruby
require "async/http"
require 'io/stream'                       # gives an async‐aware File class
require "protocol/http/body/writable"

endpoint = Async::HTTP::Endpoint.parse("https://httpbin.org/post")
headers  = [["content-type", "application/octet-stream"]]

Sync do |task|
    body = Protocol::HTTP::Body::Writable.new

    # Writer task – feeds the body from disk:
    Async do
        File.open("./some_file.txt", "rb") do |file|
            stream = IO::Stream::Buffered.wrap(file)
            while chunk = stream.read(32 * 1024)           # 32 KiB per read
                body.write(chunk)
            end
        ensure
            body.close                                    # signals EOF to the client
        end
    end

    client   = Async::HTTP::Client.new(endpoint)
    response = client.post(endpoint.path, headers, body)

    puts "status = #{response.status}"
ensure
    response&.close
    client&.close
end
```

5. For downloading files, do not call the `response.read` method, as that will load the file in memory. Instead the user should call `response.save(path)` or read the data in chunks.
```ruby
require 'async'
require 'async/http/internet/instance'

# Solution with `#save`

Sync do
	# Issue a GET request to Google:
	response = Async::HTTP::Internet.get("https://www.google.com/search?q=kittens")
	
	# Save the response body to a local file:
	response.save("/tmp/search.html")
ensure
	response&.close
end
```

```ruby
# Solution with chunking

require 'async'
require 'async/http/internet/instance'

Sync do
    response = Async::HTTP::Internet.get("https://httpbin.org/stream-bytes/1048576?chunk_size=65536")

    File.open('some_name.html', 'wb') do |file|
        while chunk = response.body.read
            file.write(chunk)
        end
    end
ensure
  response&.close
end

```
6. Be nice to remote servers by using asynchronous semaphores and timeouts.
```ruby
Sync do
	internet = ...
...
	limit = Async::Semaphore.new(4, parent: task)
	urls.each do |url|
	limit.async { puts internet.get(url).read }
...
end
```
6. A rule of thumb in the `Async::HTTP::Internet` vs `Async::HTTP::Client` debate is that `Internet` should be used for ad-hoc one-liners  and `Client` when the user needs fine-grained connection control.
