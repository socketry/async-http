# Hello Example

## Server

```bash
$ bundle update
$ bundle exec falcon serve --bind http://localhost:3000
```

## Client

### HTTP/1

```bash
$ curl -v http://localhost:3000
* Host localhost:3000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:3000...
* Connected to localhost (::1) port 3000
> GET / HTTP/1.1
> Host: localhost:3000
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 OK
< vary: accept-encoding
< content-length: 12
< 
* Connection #0 to host localhost left intact
Hello World!⏎
```

### HTTP/2

```bash
$ curl -v --http2-prior-knowledge http://localhost:3000
* Host localhost:3000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:3000...
* Connected to localhost (::1) port 3000
* [HTTP/2] [1] OPENED stream for http://localhost:3000/
* [HTTP/2] [1] [:method: GET]
* [HTTP/2] [1] [:scheme: http]
* [HTTP/2] [1] [:authority: localhost:3000]
* [HTTP/2] [1] [:path: /]
* [HTTP/2] [1] [user-agent: curl/8.7.1]
* [HTTP/2] [1] [accept: */*]
> GET / HTTP/2
> Host: localhost:3000
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
< HTTP/2 200 
< content-length: 12
< vary: accept-encoding
< 
* Connection #0 to host localhost left intact
Hello World!⏎
```
