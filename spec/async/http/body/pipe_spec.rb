# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async'
require 'async/http/body/pipe'
require 'async/http/body/writable'

RSpec.describe Async::HTTP::Body::Pipe do
	let(:input) { Async::HTTP::Body::Writable.new }
	let(:pipe) { described_class.new(input) }

	let(:data) { 'Hello World!' }

	describe '#to_io' do
		include_context Async::RSpec::Reactor

		let(:io) { pipe.to_io }

		before do
			Async::Task.current.async do |task| # input writer task
				first, second = data.split(' ')
				input.write("#{first} ")
				task.sleep(input_write_duration) if input_write_duration > 0
				input.write(second)
				input.close
			end
		end

		after { io.close }

		shared_examples :returns_io_socket do
			it 'returns an io socket' do
				expect(io).to be_a(Async::IO::Socket)
				expect(io.read).to eq data
			end
		end

		context 'when reading blocks' do
			let(:input_write_duration) { 0.01 }

			include_examples :returns_io_socket
		end

		context 'when reading does not block' do
			let(:input_write_duration) { 0 }

			include_examples :returns_io_socket
		end
	end

	describe 'going out of reactor scope' do
		context 'when pipe is closed' do
			it 'finishes' do
				Async { pipe.close }
			end
		end

		context 'when pipe is not closed' do
			it 'finishes' do # ensures pipe background tasks are transient
				Async { pipe }
			end
		end
	end
end
