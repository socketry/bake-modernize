# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "transform"

module Bake
	module Modernize
		module Gems
			def self.present?(content, name)
				content.match?(gem_line_pattern(name))
			end
			
			def self.remove(path, name)
				return false unless File.exist?(path)
				
				existing = File.read(path)
				updated = existing.lines.reject{|line| line.match?(gem_line_pattern(name))}.join
				
				return false if updated == existing
				
				File.write(path, updated)
				return true
			end
			
			def self.ensure_dependency(path, name, group:, template:)
				instruction = "Ensure the `#{name}` gem is included in the `#{group}` group. Preserve existing gems, groups, options, comments and formatting. If the `#{group}` group does not exist, create one. Do not duplicate the gem if it already exists."
				
				Bake::Modernize.transform_file(path,
					instruction: instruction,
					template: template,
					validate: -> content{present?(content, name)},
				)
			end
			
			def self.gem_line_pattern(name)
				/^\s*gem\s+["']#{Regexp.escape(name)}["'].*(?:\n|\z)/
			end
		end
	end
end
