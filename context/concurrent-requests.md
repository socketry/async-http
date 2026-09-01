# Concurrent Requests and Connection Pooling

This guide explains how to run HTTP requests concurrently while keeping request fan-out, connection usage, and resource life cycles bounded.

Concurrent requests allow independent network operations to overlap. `Async::HTTP` combines this task concurrency with persistent connection pools, but the number of request tasks and the number of connections are separate controls.

## Running Independent Requests Concurrently

When several requests do not depend on each other, start one child task for each request and then wait for their results:

~~~ ruby
require "async/http/internet/instance"
require "json"

names = ["async", "async-http", "falcon"]

versions = Sync do |task|
	tasks = names.map do |name|
		task.async do
			url = "https://rubygems.org/api/v1/gems/#{name}.json"
			
			Async::HTTP::Internet.get(url) do |response|
				raise "Could not fetch #{name}: #{response.status}" unless response.success?
				
				JSON.parse(response.read).fetch("version")
			end
		end
	end
	
	tasks.map(&:wait)
end

names.zip(versions) do |name, version|
	puts "#{name}: #{version}"
end
~~~

Each request can make progress while the others are waiting for network I/O. ruby:`Async::Task#wait` returns the task result and re-raises any failure, so request errors are not silently discarded. Results are collected in the original order even if requests finish in a different order.

The response block closes each response after its body is processed. General task creation, cancellation, and failure propagation are covered by the [`async` Tasks guide](https://socketry.github.io/async/guides/tasks/).

## Limiting Request Concurrency

Creating one task per item is appropriate for a small, fixed collection. A large or externally supplied collection should have an explicit concurrency limit so it cannot overwhelm the remote service or retain an unbounded number of pending operations.

Use ruby:`Async::Semaphore` to set a fixed request limit and ruby:`Async::Barrier` to wait for all the work:

~~~ ruby
require "async"
require "async/semaphore"
require "async/http/internet"

names = ["async", "async-http", "falcon", "protocol-http", "io-event", "console"]

Sync do
	internet = Async::HTTP::Internet.new(limit: 2)
	
	begin
		Barrier(parent: nil) do |barrier|
			requests = Async::Semaphore.new(4, parent: barrier)
			
			names.each do |name|
				requests.async do
					url = "https://rubygems.org/api/v1/gems/#{name}.json"
					
					internet.get(url) do |response|
						raise "Could not fetch #{name}: #{response.status}" unless response.success?
						
						puts "#{name}: #{response.status}"
					end
				end
			end
		end
	ensure
		internet.close
	end
end
~~~

The semaphore allows at most four request operations to run at once. The barrier tracks those tasks, waits for them to finish, propagates failures, and cancels unfinished work if the block exits early. `parent: nil` disables the barrier's load-based scheduling because the semaphore already provides an explicit limit.

See the [`async` Best Practices guide](https://socketry.github.io/async/guides/best-practices/) for general guidance on barriers, semaphores, and large workloads.

## Request Limits and Connection Limits

Request concurrency and pool capacity solve different problems:

| Control | What It Limits | Scope |
| --- | --- | --- |
| ruby:`Async::Semaphore` | Concurrent request operations and their application work. | The tasks started through that semaphore. |
| `limit` passed to ruby:`Async::HTTP::Client` | Connections held by one client pool. | One configured endpoint. |
| `limit` passed to ruby:`Async::HTTP::Internet` | Connections held by each client it creates. | Applied independently to every origin. |

The client creates connections lazily and reuses viable persistent connections. When its pool reaches `limit`, a request waits until an existing connection has capacity or is released.

For HTTP/1, a connection normally processes one request at a time, so connection capacity also constrains active requests. HTTP/2 can multiplex several request streams over one connection, so a small connection pool may support much higher request concurrency. Use a semaphore when the application needs a protocol-independent request limit; use `limit` to control connection resources.

## Releasing Connections for Reuse

A response retains pool capacity until its body is finished or closed. Always close responses promptly, especially before starting more requests that use the same limited pool:

~~~ ruby
require "async/http"

endpoint = Async::HTTP::Endpoint.parse("https://rubygems.org")

Sync do
	Async::HTTP::Client.open(endpoint, limit: 1) do |client|
		response = client.get("/api/v1/gems/async-http.json")
		
		begin
			raise "Download failed: #{response.status}" unless response.success?
			
			bytes = 0
			
			response.each do |chunk|
				bytes += chunk.bytesize
			end
			
			puts "Downloaded #{bytes} bytes."
		ensure
			response.close
		end
	end
end
~~~

The block form of ruby:`Async::HTTP::Internet` performs this cleanup automatically. When using ruby:`Async::HTTP::Client`, close the response explicitly with an `ensure` block. Holding an unread response while waiting for another request can exhaust an HTTP/1 pool and make the second request wait indefinitely.

## Pool Life Cycle

Connection pools are bound to the event loop in which they are used. Their internal maintenance task is transient, so it does not keep the event loop alive and closes the pool when the event loop exits.

Use the shared ruby:`Async::HTTP::Internet` interface when connections can remain open until the event loop exits. Use ruby:`Async::HTTP::Client.open`, or explicitly close an `Internet` or `Client`, when connections should be released earlier. See [Choosing a Client](../choosing-a-client/) for the ownership trade-offs.
