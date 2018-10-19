#!/usr/bin/env ruby

require 'async'
require 'async/http/body/file'
require 'async/http/internet'

Async.run do
	internet = Async::HTTP::Internet.new
	
	headers = [
		['accept', 'text/plain'],
	]
	
	body = Async::HTTP::Body::File.open("data.txt")
	
	response = internet.post("https://www.codeotaku.com/journal/2018-10/async-http-client-for-ruby/echo", headers, body)
	
	# response.read -> string
	# response.each {|chunk| ...}
	# response.close (forcefully ignore data)
	# body = response.finish (read and buffer response)
	response.save("echo.txt")
	
ensure
	internet.close
end
