# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Bruno Sutic.
# Copyright, 2020-2023, by Samuel Williams.

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
