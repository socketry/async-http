#!/usr/bin/env ruby

require 'async'
require 'async/http/internet'

Async do |parent|
	internet = Async::HTTP::Internet.new
	connection = nil
	
	child = parent.async do
		response = internet.get("https://utopia-falcon-heroku.herokuapp.com/beer/index")
		connection = response.connection
		
		response.each do |chunk|
			Async.logger.info(response) {chunk}
		end
	ensure
		Async.logger.info(response) {"Closing response..."}
		response&.close
	end
	
	parent.sleep(5)
	
	Async.logger.info(parent) {"Killing #{child}..."}
	child.stop
ensure
	internet&.close
end
