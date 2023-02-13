# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2023, by Samuel Williams.

require 'async/http/internet/instance'
require 'async/reactor'

RSpec.describe Async::HTTP::Internet, timeout: 5 do
	describe '.instance' do
		it "returns an internet instance" do
			expect(Async::HTTP::Internet.instance).to be_kind_of(Async::HTTP::Internet)
		end
	end
end
