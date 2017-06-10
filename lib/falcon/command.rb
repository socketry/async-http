# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'server'

require 'async/reactor'

require 'samovar'
require 'etc'

require 'rack/builder'
require 'rack/server'

module Falcon
	module Command
		def self.parse(*args)
			Top.parse(*args)
		end
		
		class Serve < Samovar::Command
			options do
				option '-c/--config <path>', "Rackup configuration file to load", default: 'config.ru'
				option '-p/--process <count>', "Number of processes to start", default: Etc.nprocessors, type: Integer
				
				option '-h/--host <address>', "Bind to the given hostname/address", default: "localhost"
				option '-p/--port <number>', "Listen on the given port", default: 9292, type: Integer
			end
			
			def run(app, options)
				server = Falcon::Server.new(app, [
					Async::IO::Address.tcp(@options[:host], @options[:port], reuse_port: true)
				])
				
				Async::Reactor.run do
					server.run
				end
			end
			
			def invoke
				app, options = Rack::Builder.parse_file(@options[:config])
				
				pids = @options[:process].times.collect do
					fork do
						self.run(app, options)
					end
				end
				
				pids.each do |pid|
					Process.wait pid
				end
			end
		end
		
		class Top < Samovar::Command
			nested '<command>',
				'serve' => Serve
				# 'get' => Get
				# 'post' => Post
				# 'head' => Head,
				# 'put' => Put,
				# 'delete' => Delete
				
			def invoke(program_name: File.basename($0))
				if @command
					@command.invoke
				else
					print_usage(program_name)
				end
			end
		end
	end
end
