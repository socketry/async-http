# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'covered/sus'
include Covered::Sus

require 'traces'
ENV['TRACES_BACKEND'] ||= 'traces/backend/test'
