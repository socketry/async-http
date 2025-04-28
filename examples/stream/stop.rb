#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "async"
require "async/http/internet"

Async do |parent|
	internet = Async::HTTP::Internet.new
	connection = nil
	
	child = parent.async do
		response = internet.get("https://utopia-falcon-heroku.herokuapp.com/beer/index")
		connection = response.connection
		
		response.each do |chunk|
			Console.info(response) {chunk}
		end
	ensure
		Console.info(response) {"Closing response..."}
		response&.close
	end
	
	parent.sleep(5)
	
	Console.info(parent) {"Killing #{child}..."}
	child.stop
ensure
	internet&.close
end
