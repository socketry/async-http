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

require 'async/http/server'
require 'async/reactor'

require 'etc'

RSpec.describe Async::HTTP::Server do
	describe "simple response" do
		it "runs quickly" do
			app = lambda do |env|
				[200, {}, ["Hello World"]]
			end

			server = Async::HTTP::Server.new([
				Async::IO::Address.tcp('127.0.0.1', 9294, reuse_port: true)
			], app)

			process_count = Etc.nprocessors

			pids = process_count.times.collect do
				fork do
					Async::Reactor.run do
						server.run
					end
				end
			end

			url = "http://127.0.0.1:9294/"
			system("ab", "-t", "2", "-c", process_count.to_s, url)
			system("wrk", "-c", process_count.to_s, "-d", "2", "-t", process_count.to_s, url)

			pids.each do |pid|
				Process.kill(:KILL, pid)
				Process.wait pid
			end
		end
	end
end
