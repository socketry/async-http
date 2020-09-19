# Async::HTTP

An asynchronous client and server implementation of HTTP/1.0, HTTP/1.1 and HTTP/2 including TLS. Support for streaming requests and responses. Built on top of [async](https://github.com/socketry/async) and [async-io](https://github.com/socketry/async-io). [falcon](https://github.com/socketry/falcon) provides a rack-compatible server.

[![Development Status](https://github.com/socketry/async-http/workflows/Development/badge.svg)](https://github.com/socketry/async-http/actions?workflow=Development)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'async-http'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install async-http

## Usage

### Post JSON data

Here is an example showing how to post a data structure as JSON to a remote resource:

``` ruby
#!/usr/bin/env ruby

require 'json'
require 'async'
require 'async/http/internet'

data = {'life' => 42}

Async do
	# Make a new internet:
	internet = Async::HTTP::Internet.new
	
	# Prepare the request:
	headers = [['accept', 'application/json']]
	body = [JSON.dump(data)]
	
	# Issues a POST request:
	response = internet.post("https://httpbin.org/anything", headers, body)
	
	# Save the response body to a local file:
	pp JSON.parse(response.read)
ensure
	# The internet is closed for business:
	internet.close
end
```

Consider using [async-rest](https://github.com/socketry/async-rest) instead.

### Multiple Requests

To issue multiple requests concurrently, you should use a barrier, e.g.

``` ruby
#!/usr/bin/env ruby

require 'async'
require 'async/barrier'
require 'async/http/internet'

TOPICS = ["ruby", "python", "rust"]

Async do
	internet = Async::HTTP::Internet.new
	barrier = Async::Barrier.new
	
	# Spawn an asynchronous task for each topic:
	TOPICS.each do |topic|
		barrier.async do
			response = internet.get "https://www.google.com/search?q=#{topic}"
			puts "Found #{topic}: #{response.read.scan(topic).size} times."
		end
	end
	
	# Ensure we wait for all requests to complete before continuing:
	barrier.wait
ensure
	internet&.close
end
```

#### Limiting Requests

If you need to limit the number of simultaneous requests, use a semaphore.

``` ruby
#!/usr/bin/env ruby

require 'async'
require 'async/barrier'
require 'async/semaphore'
require 'async/http/internet'

TOPICS = ["ruby", "python", "rust"]

Async do
	internet = Async::HTTP::Internet.new
	barrier = Async::Barrier.new
	semaphore = Async::Semaphore.new(2, parent: barrier)
	
	# Spawn an asynchronous task for each topic:
	TOPICS.each do |topic|
		semaphore.async do
			response = internet.get "https://www.google.com/search?q=#{topic}"
			puts "Found #{topic}: #{response.read.scan(topic).size} times."
		end
	end
	
	# Ensure we wait for all requests to complete before continuing:
	barrier.wait
ensure
	internet&.close
end
```

### Downloading a File

Here is an example showing how to download a file and save it to a local path:

``` ruby
#!/usr/bin/env ruby

require 'async'
require 'async/http/internet'

Async do
	# Make a new internet:
	internet = Async::HTTP::Internet.new
	
	# Issues a GET request to Google:
	response = internet.get("https://www.google.com/search?q=kittens")
	
	# Save the response body to a local file:
	response.save("/tmp/search.html")
ensure
	# The internet is closed for business:
	internet.close
end
```

### Basic Client/Server

Here is a basic example of a client/server running in the same reactor:

``` ruby
#!/usr/bin/env ruby

require 'async'
require 'async/http/server'
require 'async/http/client'
require 'async/http/endpoint'
require 'async/http/protocol/response'

endpoint = Async::HTTP::Endpoint.parse('http://127.0.0.1:9294')

app = lambda do |request|
	Protocol::HTTP::Response[200, {}, ["Hello World"]]
end

server = Async::HTTP::Server.new(app, endpoint)
client = Async::HTTP::Client.new(endpoint)
	
Async do |task|
	server_task = task.async do
		server.run
	end
	
	response = client.get("/")
	
	puts response.status
	puts response.read
	
	server_task.stop
end
```

### Advanced Verification

You can hook into SSL certificate verification to improve server verification.

``` ruby
require 'async'
require 'async/http'

# These are generated from the certificate chain that the server presented.
trusted_fingerprints = {
	"dac9024f54d8f6df94935fb1732638ca6ad77c13" => true,
	"e6a3b45b062d509b3382282d196efe97d5956ccb" => true,
	"07d63f4c05a03f1c306f9941b8ebf57598719ea2" => true,
	"e8d994f44ff20dc78dbff4e59d7da93900572bbf" => true,
}

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://www.codeotaku.com/index")
	
	# This is a quick hack/POC:
	ssl_context = endpoint.ssl_context
	
	ssl_context.verify_callback = proc do |verified, store_context|
		certificate = store_context.current_cert
		fingerprint = OpenSSL::Digest::SHA1.new(certificate.to_der).to_s
		
		if trusted_fingerprints.include? fingerprint
			true
		else
			Async.logger.warn("Untrusted Certificate Fingerprint"){fingerprint}
			false
		end
	end
	
	endpoint = endpoint.with(ssl_context: ssl_context)
	
	client = Async::HTTP::Client.new(endpoint)
	
	response = client.get(endpoint.path)
	
	pp response.status, response.headers.fields, response.read
end
```

### Timeouts

Here's a basic example with a timeout:

``` ruby
#!/usr/bin/env ruby

require 'async/http/internet'

Async do |task|
	internet = Async::HTTP::Internet.new
	
	# Request will timeout after 2 seconds
	task.with_timeout(2) do
		response = internet.get "https://httpbin.org/delay/10"
	end
rescue Async::TimeoutError
	puts "The request timed out"
ensure
	internet&.close
end
```

## Performance

On a 4-core 8-thread i7, running `ab` which uses discrete (non-keep-alive) connections:

    $ ab -c 8 -t 10 http://127.0.0.1:9294/
    This is ApacheBench, Version 2.3 <$Revision: 1757674 $>
    Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
    Licensed to The Apache Software Foundation, http://www.apache.org/
    
    Benchmarking 127.0.0.1 (be patient)
    Completed 5000 requests
    Completed 10000 requests
    Completed 15000 requests
    Completed 20000 requests
    Completed 25000 requests
    Completed 30000 requests
    Completed 35000 requests
    Completed 40000 requests
    Completed 45000 requests
    Completed 50000 requests
    Finished 50000 requests
    
    
    Server Software:        
    Server Hostname:        127.0.0.1
    Server Port:            9294
    
    Document Path:          /
    Document Length:        13 bytes
    
    Concurrency Level:      8
    Time taken for tests:   1.869 seconds
    Complete requests:      50000
    Failed requests:        0
    Total transferred:      2450000 bytes
    HTML transferred:       650000 bytes
    Requests per second:    26755.55 [#/sec] (mean)
    Time per request:       0.299 [ms] (mean)
    Time per request:       0.037 [ms] (mean, across all concurrent requests)
    Transfer rate:          1280.29 [Kbytes/sec] received
    
    Connection Times (ms)
                  min  mean[+/-sd] median   max
    Connect:        0    0   0.0      0       0
    Processing:     0    0   0.2      0       6
    Waiting:        0    0   0.2      0       6
    Total:          0    0   0.2      0       6
    
    Percentage of the requests served within a certain time (ms)
      50%      0
      66%      0
      75%      0
      80%      0
      90%      0
      95%      1
      98%      1
      99%      1
     100%      6 (longest request)

On a 4-core 8-thread i7, running `wrk`, which uses 8 keep-alive connections:

    $ wrk -c 8 -d 10 -t 8 http://127.0.0.1:9294/
    Running 10s test @ http://127.0.0.1:9294/
      8 threads and 8 connections
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency   217.69us    0.99ms  23.21ms   97.39%
        Req/Sec    12.18k     1.58k   17.67k    83.21%
      974480 requests in 10.10s, 60.41MB read
    Requests/sec:  96485.00
    Transfer/sec:      5.98MB

According to these results, the cost of handling connections is quite high, while general throughput seems pretty decent.

## Semantic Model

### Scheme

HTTP/1 has an implicit scheme determined by the kind of connection made to the server (either `http` or `https`), while HTTP/2 models this explicitly and the client indicates this in the request using the `:scheme` pseudo-header (typically `https`). To normalize this, `Async::HTTP::Client` and `Async::HTTP::Server` have a default scheme which is used if none is supplied.

### Version

HTTP/1 has an explicit version while HTTP/2 does not expose the version in any way.

### Reason

HTTP/1 responses contain a reason field which is largely irrelevant. HTTP/2 does not support this field.

## Contributing

1.  Fork it
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create new Pull Request

## See Also

  - [benchmark-http](https://github.com/socketry/benchmark-http) — A benchmarking tool to report on web server concurrency.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-rest](https://github.com/socketry/async-rest) — A RESTful resource layer built on top of `async-http`.
  - [async-http-faraday](https://github.com/socketry/async-http-faraday) — A faraday adapter to use `async-http`.

## License

Released under the MIT license.

Copyright, 2018, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
