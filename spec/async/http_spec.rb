require "spec_helper"

RSpec.describe Async::HTTP do
	it "has a version number" do
		expect(Async::HTTP::VERSION).not_to be nil
	end

	it "does something useful" do
		expect(false).to eq(true)
	end
end
