# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.

require "async/http/internet/instance"

describe Async::HTTP::Internet do
	describe ".instance" do
		it "returns an internet instance" do
			expect(Async::HTTP::Internet.instance).to be_a(Async::HTTP::Internet)
		end
	end
end
