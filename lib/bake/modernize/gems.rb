# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "transform"

module Bake
	module Modernize
		# Provides helpers for updating Ruby gem dependency files.
		module Gems
			# Check whether the given content declares the named gem dependency.
			# @parameter content [String] The dependency file content to inspect.
			# @parameter name [String] The gem name to find.
			# @returns [bool] True if the gem is declared.
			def self.present?(content, name)
				content.match?(gem_line_pattern(name))
			end
			
			# Remove the named gem dependency from the given file using a deterministic line edit.
			# @parameter path [String] The path to the dependency file.
			# @parameter name [String] The gem name to remove.
			# @returns [bool] True if the file was changed.
			def self.remove(path, name)
				return false unless File.exist?(path)
				
				existing = File.read(path)
				updated = existing.lines.reject{|line| line.match?(gem_line_pattern(name))}.join
				
				return false if updated == existing
				
				File.write(path, updated)
				return true
			end
			
			# Ensure the named gem dependency exists using a validated transform.
			# @parameter path [String] The path to the dependency file.
			# @parameter name [String] The gem name to add.
			# @parameter group [Symbol] The dependency group that should contain the gem.
			# @parameter template [String] The desired dependency file shape to use as transform guidance.
			# @returns [bool] True if the file was changed.
			# @raises [ArgumentError] If the transform output does not include the gem.
			def self.ensure_dependency(path, name, group:, template:)
				instruction = "Ensure the `#{name}` gem is included in the `#{group}` group. Preserve existing gems, groups, options, comments and formatting. If the `#{group}` group does not exist, create one. Do not duplicate the gem if it already exists."
				
				Bake::Modernize.transform_file(path,
					instruction: instruction,
					template: template,
					validate: -> content{present?(content, name)},
				)
			end
			
			# Build a regular expression for matching a simple gem declaration line.
			# @parameter name [String] The gem name to match.
			# @returns [Regexp] A regular expression that matches the gem declaration line.
			def self.gem_line_pattern(name)
				/^\s*gem\s+["']#{Regexp.escape(name)}["'].*(?:\n|\z)/
			end
		end
	end
end
