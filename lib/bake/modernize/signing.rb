# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Bake
	module Modernize
		# Resolve the RubyGems signing certificate and private key for a project.
		class Signing
			GEM_CREDENTIALS_PATH = File.expand_path("~/.gem")
			GITHUB_OWNER = %r{\Ahttps?://github\.com/([\w.-]+)/}

			# Load signing configuration from a project's gemspec.
			# @parameter root [String] The project root.
			# @returns [Signing] The signing configuration.
			def self.load(root)
				gemspec_path = Dir["*.gemspec", base: root].first
				gemspec = Gem::Specification.load(File.join(root, gemspec_path)) if gemspec_path

				return new(gemspec)
			end

			# @parameter gemspec [Gem::Specification | Nil] The project gemspec.
			def initialize(gemspec)
				@gemspec = gemspec
			end

			# The preferred certificate, if available.
			# @returns [String | Nil] The certificate path.
			def certificate_path
				paths = []

				if owner = signing_owner
					paths << File.join(GEM_CREDENTIALS_PATH, "#{owner}-release.cert")
				end

				paths << File.join(GEM_CREDENTIALS_PATH, "release.cert")
				return paths.find{|path| File.file?(path)}
			end

			# The private key path, preserving an existing gemspec setting.
			# @returns [String] The private key path.
			def private_key_path
				return @gemspec.signing_key if @gemspec&.signing_key

				if certificate_path = self.certificate_path
					return certificate_path.sub(/\.cert\z/, ".pem")
				end

				return File.join(GEM_CREDENTIALS_PATH, "release.pem")
			end

			# Format a private key path for use in a gemspec.
			# @returns [String] A Ruby expression.
			def private_key_expression
				prefix = GEM_CREDENTIALS_PATH + File::SEPARATOR
				path = self.private_key_path

				if path.start_with?(prefix)
					relative_path = path.delete_prefix(prefix)
					path = "~/.gem/#{relative_path}"
					return "File.expand_path(#{path.inspect})"
				end

				return path.inspect
			end

			private

			def signing_owner
				return unless @gemspec

				owner = @gemspec.metadata["signing_owner"]
				return owner if owner&.match?(/\A[\w.-]+\z/)

				urls = [@gemspec.metadata["source_code_uri"], @gemspec.homepage].compact
				urls.each do |url|
					if match = GITHUB_OWNER.match(url)
						return match[1]
					end
				end
			end
		end
	end
end
