# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2026, by Samuel Williams.

require_relative "modernize/git"
require_relative "modernize/license"
require_relative "modernize/transform"
require_relative "modernize/gems"
require_relative "modernize/version"

require "build/files/glob"
require "fileutils"

# @namespace
module Bake
	# @namespace
	module Modernize
		ROOT = File.expand_path("../..", __dir__)
		
		TEMPLATE_ROOT = Build::Files::Path.new(ROOT) + "template"
		
		# Compute the template root path relative to the gem root.
		def self.template_path_for(path)
			TEMPLATE_ROOT + path
		end
		
		# Check if the destination path is stale compared to the source path.
		def self.stale?(source_path, destination_path)
			if File.exist?(destination_path)
				return !FileUtils.identical?(source_path, destination_path)
			end
			
			return true
		end
		
		# Copy files from the source path to the destination path.
		#
		# @parameter source_path [String] The source path.
		# @parameter destination_path [String] The destination path.
		def self.copy_template(source_path, destination_path)
			glob = Build::Files::Glob.new(source_path, "**/*")
			
			glob.each do |path|
				full_path = File.join(destination_path, path.relative_path)
				
				if File.directory?(path)
					unless File.directory?(full_path)
						FileUtils.mkdir_p(full_path)
					end
				else
					if stale?(path, full_path)
						FileUtils::Verbose.cp(path, full_path)
					end
				end
			end
		end
	end
end
