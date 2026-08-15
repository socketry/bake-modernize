# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

source "https://rubygems.org"

gemspec

group :test do
	gem "rubocop"
	gem "rubocop-md"
	gem "rubocop-socketry"
end
