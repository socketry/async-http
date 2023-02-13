#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require 'async'
require_relative '../../lib/async/http/endpoint'
require '../../lib/async/http/client'

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://programming.dojo.net.nz", protocol: Async::HTTP::Protocol::HTTP10)
	client = Async::HTTP::Client.new(endpoint)
	
	response = client.get("programming.dojo.net.nz")
	puts response, response.read
end
