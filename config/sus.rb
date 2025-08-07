# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.

# ENV["CONSOLE_LEVEL"] ||= "fatal"

require "covered/sus"
include Covered::Sus

ENV["TRACES_BACKEND"] ||= "traces/backend/test"
ENV["METRICS_BACKEND"] ||= "metrics/backend/test"

def prepare_instrumentation!
	require "traces"
	require "metrics"
end

def before_tests(...)
	prepare_instrumentation!
	
	super
end