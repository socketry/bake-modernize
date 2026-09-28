# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Bake
	module Modernize
		# Resolve the RubyGems signing certificate and private key for a project.
		class Signing
			GEM_CREDENTIALS_PATH = File.expand_path("~/.gem")
			GITHUB_OWNER = %r{\Ahttps?://github\.com/([\w.-]+)/}

			attr_reader :certificate_path, :private_key_path

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
				owner = signing_owner(gemspec)
				certificate_paths = []

				if owner
					certificate_paths << File.join(GEM_CREDENTIALS_PATH, "#{owner}-release.cert")
				end

				certificate_paths << File.join(GEM_CREDENTIALS_PATH, "release.cert")
				@certificate_path = certificate_paths.find{|path| File.file?(path)}

				@private_key_path = if gemspec&.signing_key
					gemspec.signing_key
				elsif @certificate_path
					@certificate_path.sub(/\.cert\z/, ".pem")
				else
					File.join(GEM_CREDENTIALS_PATH, "release.pem")
				end
			end

			# Format a private key path for use in a gemspec.
			# @returns [String] A Ruby expression.
			def private_key_expression
				prefix = GEM_CREDENTIALS_PATH + File::SEPARATOR

				if @private_key_path.start_with?(prefix)
					relative_path = @private_key_path.delete_prefix(prefix)
					path = "~/.gem/#{relative_path}"
					return "File.expand_path(#{path.inspect})"
				end

				return @private_key_path.inspect
			end

			private

			def signing_owner(gemspec)
				return unless gemspec

				owner = gemspec.metadata["signing_owner"]
				return owner if owner&.match?(/\A[\w.-]+\z/)

				urls = [gemspec.metadata["source_code_uri"], gemspec.homepage].compact
				urls.each do |url|
					return match[1] if match = GITHUB_OWNER.match(url)
				end
			end
		end
	end
end
