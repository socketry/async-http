# Releases

## Unreleased

### `Async::HTTP::Internet` accepts keyword arguments

`Async::HTTP::Internet` now accepts keyword arguments for making a request, e.g.

```ruby
internet = Async::HTTP::Internet.instance

# This will let you override the authority (HTTP/1.1 host header, HTTP/2 :authority header):
internet.get("https://proxy.local", authority: "example.com")

# This will let you override the scheme:
internet.get("https://example.com", scheme: "http")
```

## v0.73.0

### Update support for `interim_response`

`Protocol::HTTP::Request` now supports an `interim_response` callback, which will be called with the interim response status and headers. This works on both the client and the server:

```ruby
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
