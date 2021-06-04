#!/usr/bin/env ruby

require 'async'
require 'async/http/server'
require 'async/http/endpoint'
require 'async/http/protocol/response'

endpoint = Async::HTTP::Endpoint.parse('http://127.0.0.1:8080')

app = lambda do |request|
	Protocol::HTTP::Response[200, {}, [request.path[1..-1]]]
end

server = Async::HTTP::Server.new(app, endpoint)

Async do |task|
	server.run
end
