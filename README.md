# Async::HTTP

A multi-process, multi-fiber HTTP client/server built on top of [async] and [async-io]. Each request is run within a light weight fiber and can block on up-stream requests without stalling the entire server process.

*This code is a proof-of-concept and not intended (yet) for production use.* The entire stack requires more scrutiny both in terms of performance and security.

[![Build Status](https://secure.travis-ci.org/socketry/async-http.svg)](http://travis-ci.org/socketry/async-http)
[![Code Climate](https://codeclimate.com/github/socketry/async-http.svg)](https://codeclimate.com/github/socketry/async-http)
[![Coverage Status](https://coveralls.io/repos/socketry/async-http/badge.svg)](https://coveralls.io/r/socketry/async-http)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'async-http'
```

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install async-http

## Usage

Here is a basic example of a client/server running in the same reactor:

```ruby
require 'async/http/server'
require 'async/http/client'
require 'async/reactor'

server_addresses = [
	Async::IO::Address.tcp('127.0.0.1', 9294, reuse_port: true)
]

app = lambda do |env|
	[200, {}, ["Hello World"]]
end

server = Async::HTTP::Server.new(server_addresses, app)
client = Async::HTTP::Client.new(server_addresses)
	
Async::Reactor.run do |task|
	server_task = task.async do
		server.run
	end
	
	response = client.get("/", {})
	puts response.body
	
	server_task.stop
end
```

## Performance

On a 4-core 8-thread i7, running `ab` which uses discrete (non-keep-alive) connections:

```
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
```

On a 4-core 8-thread i7, running `wrk`, which uses 8 keep-alive connections:

```
$ wrk -c 8 -d 10 -t 8 http://127.0.0.1:9294/
Running 10s test @ http://127.0.0.1:9294/
  8 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   217.69us    0.99ms  23.21ms   97.39%
    Req/Sec    12.18k     1.58k   17.67k    83.21%
  974480 requests in 10.10s, 60.41MB read
Requests/sec:  96485.00
Transfer/sec:      5.98MB
```

According to these results, the cost of handling connections is quite high, while general throughput seems pretty decent.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2015, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

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
