# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

source "https://rubygems.org"

gemspec

group :documentation do
	gem "decode"
end

group :test do
	gem "bake-test"
	gem "bake-test-external"
end
