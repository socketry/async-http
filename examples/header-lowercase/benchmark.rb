# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "benchmark/ips"

class NormalizedHeaders
	def initialize(fields)
		@fields = fields
	end
	
	def [](key)
		@fields[key.downcase]
	end
end

class Headers
	def initialize(fields)
		@fields = fields
	end
	
	def [](key)
		@fields[key]
	end
end

FIELDS = {
	"content-type" => "text/html",
	"content-length" => "127889",
	"accept-ranges" => "bytes",
	"date" => "Tue, 14 Jul 2015 22:00:02 GMT",
	"via" => "1.1 varnish",
	"age" => "0",
	"connection" => "keep-alive",
	"x-served-by" => "cache-iad2125-IAD",
}

NORMALIZED_HEADERS = NormalizedHeaders.new(FIELDS)
HEADERS = Headers.new(FIELDS)

Benchmark.ips do |x|
	x.report("NormalizedHeaders[Content-Type]") { NORMALIZED_HEADERS["Content-Type"] }
	x.report("NormalizedHeaders[content-type]") { NORMALIZED_HEADERS["content-type"] }
	x.report("Headers") { HEADERS["content-type"] }
	
	x.compare!
end
