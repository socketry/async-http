#!/usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'async-http', '0.56.1'
  gem 'protocol-http', '0.22.0'
end

require 'async/http/internet'

Async do
  internet = Async::HTTP::Internet.new
  url = "http://httpbin.org/gzip"
  # headers = ["accept-encoding", "gzip"]
  headers = {"accept-encoding" => "gzip"}
  response = internet.get(url, headers)
  puts response.read
ensure
	internet&.close
end
