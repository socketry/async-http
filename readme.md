# Async::HTTP

An asynchronous client and server implementation of HTTP/1.0, HTTP/1.1 and HTTP/2 including TLS. Support for streaming requests and responses. Built on top of [async](https://github.com/socketry/async), [io-endpoint](https://github.com/socketry/io-endpoint) and [io-stream](https://github.com/socketry/io-stream). [falcon](https://github.com/socketry/falcon) provides a rack-compatible server.

[![Development Status](https://github.com/socketry/async-http/workflows/Test/badge.svg)](https://github.com/socketry/async-http/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-http/) for more details.

  - [Getting Started](https://socketry.github.io/async-http/guides/getting-started/index) - This guide explains how to make HTTP requests and serve HTTP responses with `Async::HTTP`.

  - [Choosing a Client](https://socketry.github.io/async-http/guides/choosing-a-client/index) - This guide explains how to choose between ruby:`Async::HTTP::Internet`, ruby:`Async::HTTP::Client`, and higher-level interfaces for libraries.

  - [Concurrent Requests and Connection Pooling](https://socketry.github.io/async-http/guides/concurrent-requests/index) - This guide explains how to run HTTP requests concurrently while keeping request fan-out, connection usage, and resource life cycles bounded.

  - [Testing](https://socketry.github.io/async-http/guides/testing/index) - This guide explains how to test `Async::HTTP` clients and servers without depending on external HTTP services.

## Releases

Please see the [project releases](https://socketry.github.io/async-http/releases/index) for all releases.

### v0.102.0

  - Requests assigned to an HTTP/2 connection which has already closed are refused before being written, allowing them to be retried safely.
  - HTTP/2 connections which received a graceful `GOAWAY` are removed from availability immediately, but remain in the pool until the server has finished answering the streams it accepted. The connection is closed after its final user releases it, so those requests no longer fail with `EOFError: Connection closed with N active stream(s)!`.

### v0.101.0

  - Handle remote disconnects in `Async::HTTP::Protocol::HTTP1::Server#each` without reporting them as server failures.

### v0.100.0

  - Added transport-neutral TLS configuration support to `Async::HTTP::Endpoint`.

### v0.99.0

  - Retry safe requests when a remote HTTP/2 endpoint resets the stream with `INTERNAL_ERROR` before returning a response.

### v0.98.1

  - Probe idle HTTP/1 connections before reuse, avoiding requests on connections already closed by the peer.

### v0.98.0

  - Rewind request bodies before retrying requests.

### v0.97.0

  - Exposed all supported protocol names from the plaintext HTTP protocol negotiator.

### v0.96.0

  - Made `metrics` and `traces` optional runtime dependencies. Applications that use the providers should depend on the corresponding gem and require the provider explicitly.

### v0.95.1

  - Fix handling of reset stream causing complete connection failure.

### v0.95.0

  - Use `Protocol::HTTP::RefusedError` for safe retry of requests not processed by the server, including non-idempotent methods like PUT.
      - Remove `Async::HTTP::Protocol::RequestFailed` in favour of `Protocol::HTTP::RefusedError`.
      - HTTP/1: Delegate request write failure handling to `protocol-http1`.
      - HTTP/2: Handle GOAWAY and REFUSED\_STREAM via `protocol-http2`, enabling automatic retry of unprocessed requests.

## See Also

  - [benchmark-http](https://github.com/socketry/benchmark-http) — A benchmarking tool to report on web server concurrency.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-rest](https://github.com/socketry/async-rest) — A RESTful resource layer built on top of `async-http`.
  - [async-http-faraday](https://github.com/socketry/async-http-faraday) — A faraday adapter to use `async-http`.

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To make a new release:

``` bash
$ bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
