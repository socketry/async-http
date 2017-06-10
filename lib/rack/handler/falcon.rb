
require 'rack/handler'

require_relative '../../falcon'

module Rack
	module Handler
		module Falcon
			def self.run(app, **options)
				Async::Reactor.run
					server = Falcon::Server.new(app, **options)
					
					server.run
				end
			end
			
			def self.valid_options
				{
					"host=HOST" => "Hostname to listen on (default: localhost)",
					"port=PORT" => "Port to listen on (default: 8080)",
					"verbose" => "Don't report each request (default: false)"
				}
			end
		end
		
		register :falcon, Falcon
	end
end
