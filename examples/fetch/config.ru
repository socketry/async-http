# frozen_string_literal: true

require 'rack'

class Echo
	def initialize(app)
		@app = app
	end
	
	def call(env)
		request = Rack::Request.new(env)
		
		if request.path_info == "/echo"
			if output = request.body
				return [200, {}, output.body]
			else
				return [200, {}, ["Hello World?"]]
			end
		else
			return @app.call(env)
		end
	end
end

use Echo

use Rack::Static, :urls => [''], :root => 'public', :index => 'index.html'

run lambda{|env| [404, {}, []]}
