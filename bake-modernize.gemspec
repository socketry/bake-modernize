# frozen_string_literal: true

require_relative "lib/bake/modernize/version"

Gem::Specification.new do |spec|
	spec.name = "bake-modernize"
	spec.version = Bake::Modernize::VERSION
	
	spec.summary = "Automatically modernize parts of your project/gem."
	spec.authors = ["Samuel Williams", "Olle Jonsson", "Copilot"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/socketry-release.pem")
	
	spec.homepage = "https://github.com/ioquatix/bake-modernize"
	
	spec.metadata = {
		"bug_tracker_uri" => "https://github.com/ioquatix/bake-modernize/issues",
		"changelog_uri" => "https://github.com/ioquatix/bake-modernize/blob/main/releases.md",
		"documentation_uri" => "https://ioquatix.github.io/bake-modernize/",
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
		"source_code_uri" => "https://github.com/ioquatix/bake-modernize.git",
	}
	
	spec.files = Dir.glob(["{bake,lib,template}/**/*", "*.md", "release.cert"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "async-http"
	spec.add_dependency "async-ollama", "~> 0.10"
	spec.add_dependency "bake"
	spec.add_dependency "build-files", "~> 1.6"
	spec.add_dependency "markly", "~> 0.13"
	spec.add_dependency "rugged"
end
