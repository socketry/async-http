# Releases

## Unreleased

  - Minor consistency fixes to `Async::HTTP::Internet` singleton methods.

## v0.82.0

  - `protocol-http1` introduces a line length limit for request line, response line, header lines and chunk length lines.

## v0.81.0

  - Expose `protocol` and `endpoint` as tags to `async-pool` for improved instrumentation.

## v0.77.0

  - Improved HTTP/1 connection handling.
  - The input stream is no longer closed when the output stream is closed.

## v0.76.0

  - `Async::HTTP::Body::Writable` is moved to `Protocol::HTTP::Body::Writable`.
  - Remove `Async::HTTP::Body::Delayed` with no replacement.
  - Remove `Async::HTTP::Body::Slowloris` with no replacement.

## v0.75.0

  - Better handling of HTTP/1 \<-\> HTTP/2 proxying, specifically upgrade/CONNECT requests.

## v0.74.0

### `Async::HTTP::Internet` accepts keyword arguments

`Async::HTTP::Internet` now accepts keyword arguments for making a request, e.g.

``` ruby
internet = Async::HTTP::Internet.instance

# This will let you override the authority (HTTP/1.1 host header, HTTP/2 :authority header):
internet.get("https://proxy.local", authority: "example.com")

# This will let you override the scheme:
internet.get("https://example.com", scheme: "http")
```

## v0.73.0

### Update support for `interim_response`

`Protocol::HTTP::Request` now supports an `interim_response` callback, which will be called with the interim response status and headers. This works on both the client and the server:

``` ruby
# Server side:
def call(request)
	if request.headers['expect'].include?('100-continue')
		request.send_interim_response(100)
	end
	
	# ...
end

# Client side:
body = Async::HTTP::Body::Writable.new

interim_repsonse = proc do |status, headers|
	if status == 100
		# Continue sending the body...
		body.write("Hello, world!")
		body.close
	end
end

Async::HTTP::Internet.instance.post("https://example.com", body, interim_response: interim_response) do |response|
	unless response.success?
		body.close
	end
end
```
