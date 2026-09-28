# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Bake
	module Modernize
		# Helpers for locating the RubyGems signing certificate and private key.
		module Signing
			GEM_CREDENTIALS_PATH = File.expand_path("~/.gem")
			GITHUB_OWNER = %r{\Ahttps?://github\.com/([\w.-]+)/}

			# The preferred certificate for a project, if available.
			# @parameter root [String] The project root.
			# @returns [String | Nil] The certificate path.
			def self.certificate_path(root)
				paths = []

				if owner = signing_owner(root)
					paths << File.join(GEM_CREDENTIALS_PATH, "#{owner}-release.cert")
				end

				paths << File.join(GEM_CREDENTIALS_PATH, "release.cert")

				return paths.find{|path| File.file?(path)}
			end

			# The preferred private key path for a project.
			# @parameter root [String] The project root.
			# @returns [String] The private key path.
			def self.private_key_path(root)
				certificate_path = self.certificate_path(root)
				return certificate_path.sub(/\.cert\z/, ".pem") if certificate_path

				return File.join(GEM_CREDENTIALS_PATH, "release.pem")
			end

			# Format a private key path for use in a gemspec.
			# @parameter path [String] The private key path.
			# @returns [String] A Ruby expression.
			def self.private_key_expression(path)
				prefix = GEM_CREDENTIALS_PATH + File::SEPARATOR

				if path.start_with?(prefix)
					relative_path = path.delete_prefix(prefix)
					path = "~/.gem/#{relative_path}"
					return "File.expand_path(#{path.inspect})"
				end

				return path.inspect
			end

			# The signing owner for the project's gemspec, falling back to its GitHub URL.
			# @parameter root [String] The project root.
			# @returns [String | Nil] The signing owner.
			def self.signing_owner(root)
				gemspec_path = Dir["*.gemspec", base: root].first
				return unless gemspec_path

				spec = Gem::Specification.load(File.join(root, gemspec_path))
				return unless spec

				owner = spec.metadata["signing_owner"]
				return owner if owner&.match?(/\A[\w.-]+\z/)

				urls = [spec.metadata["source_code_uri"], spec.homepage].compact
				urls.each do |url|
					return match[1] if match = GITHUB_OWNER.match(url)
				end
			end
		end
	end
end
