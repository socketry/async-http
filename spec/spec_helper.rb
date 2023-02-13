# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.

require 'traces'

require 'bundler/setup'
require 'covered/rspec'

require 'async/rspec'

ENV['TRACES_BACKEND'] ||= 'traces/backend/test'

RSpec.shared_context 'docstring as description' do
	let(:description) {self.class.metadata.fetch(:description_args).first}
end

RSpec.configure do |config|
	# Enable flags like --only-failures and --next-failure
	config.example_status_persistence_file_path = ".rspec_status"

	config.include_context 'docstring as description'

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end
