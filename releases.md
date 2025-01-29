# Releases

## v0.87.0

### Unify HTTP/1 and HTTP/2 `CONNECT` semantics

HTTP/1 has a request line "target" which takes different forms depending on the kind of request. For `CONNECT` requests, the target is the authority (host and port) of the target server, e.g.

    CONNECT example.com:443 HTTP/1.1

In HTTP/2, the `CONNECT` method uses the `:authority` pseudo-header to specify the target, e.g.

``` http
[HEADERS FRAME]
:method: connect
:authority: example.com:443
```

In HTTP/1, the `Request#path` attribute was previously used to store the target, and this was incorrectly mapped to the `:path` pseudo-header in HTTP/2. This has been corrected, and the `Request#authority` attribute is now used to store the target for both HTTP/1 and HTTP/2, and mapped accordingly. Thus, to make a `CONNECT` request, you should set the `Request#authority` attribute, e.g.

``` ruby
response = client.connect(authority: "example.com:443")
```

For HTTP/1, the authority is mapped back to the request line target, and for HTTP/2, it is mapped to the `:authority` pseudo-header.

## v0.86.0

  - Add support for HTTP/2 `NO_RFC7540_PRIORITIES`. See <https://www.rfc-editor.org/rfc/rfc9218.html> for more details.

## v0.84.0

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
