# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2018, by Janko Marohnić.

ENV['CONSOLE_LEVEL'] ||= 'fatal'

require 'covered/sus'
include Covered::Sus

require 'traces'
ENV['TRACES_BACKEND'] ||= 'traces/backend/test'
