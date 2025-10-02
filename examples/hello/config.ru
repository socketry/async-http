#!/usr/bin/env falcon --verbose serve -c
# frozen_string_literal: true

require "async"
require "async/barrier"
require "net/http"
require "uri"

run do |env|
	i = 1_000_000
	while i > 0
		i -= 1
	end
	
	[200, {}, ["Hello World!"]]
end
