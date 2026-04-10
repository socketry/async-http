# Async::HTTP

An asynchronous client and server implementation of HTTP/1.0, HTTP/1.1 and HTTP/2 including TLS. Support for streaming requests and responses. Built on top of [async](https://github.com/socketry/async), [io-endpoint](https://github.com/socketry/io-endpoint) and [io-stream](https://github.com/socketry/io-stream). [falcon](https://github.com/socketry/falcon) provides a rack-compatible server.

[![Development Status](https://github.com/socketry/async-http/workflows/Test/badge.svg)](https://github.com/socketry/async-http/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-http/) for more details.

  - [Getting Started](https://socketry.github.io/async-http/guides/getting-started/index) - This guide explains how to get started with `Async::HTTP`.

  - [Testing](https://socketry.github.io/async-http/guides/testing/index) - This guide explains how to use `Async::HTTP` clients and servers in your tests.

## Releases

Please see the [project releases](https://socketry.github.io/async-http/releases/index) for all releases.

### v0.94.3

  - Fix response body leak in HTTP/2 server when stream is reset before `send_response` completes (e.g. client-side gRPC cancellation). The response body's `close` was never called, leaking any resources tied to body lifecycle (such as `rack.response_finished` callbacks and utilization metrics).

### v0.94.1

  - Fix `defer_stop` usage in `HTTP1::Server`, improving server graceful shutdown behavior.

### v0.94.0

  - Propagate all errors from background reader to active streams so that they are closed correctly (e.g. errors are not missed).

### v0.92.2

  - Better handling of trailers. If invalid trailers are received, the connection (HTTP/1) or stream (HTTP/2) is reset.

### v0.92.0

  - **Breaking**: Remove `Async::HTTP::Reference`. Use `Protocol::URL::Reference` directly instead.

### v0.91.0

  - Move all default trace providers into `traces/provider/async/http`.

### v0.90.2

  - Don't emit `resource:` keyword argument in traces - it's unsupported by OpenTelemetry.

### v0.88.0

  - [Support custom protocols with options](https://socketry.github.io/async-http/releases/index#support-custom-protocols-with-options)

### v0.87.0

  - [Unify HTTP/1 and HTTP/2 `CONNECT` semantics](https://socketry.github.io/async-http/releases/index#unify-http/1-and-http/2-connect-semantics)

### v0.86.0

  - Add support for HTTP/2 `NO_RFC7540_PRIORITIES`. See <https://www.rfc-editor.org/rfc/rfc9218.html> for more details.

## See Also

  - [benchmark-http](https://github.com/socketry/benchmark-http) — A benchmarking tool to report on web server concurrency.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-rest](https://github.com/socketry/async-rest) — A RESTful resource layer built on top of `async-http`.
  - [async-http-faraday](https://github.com/socketry/async-http-faraday) — A faraday adapter to use `async-http`.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Running Tests

To run the test suite:

``` shell
bundle exec sus
```

### Making Releases

To make a new release:

``` shell
bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
