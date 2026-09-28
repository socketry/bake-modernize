# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2026, by Samuel Williams.

require "bake/modernize"

# Rewrite the current gemspec.
def gemspec
	path = default_gemspec_path
	buffer = StringIO.new
	
	update(path: path, output: buffer)
	
	File.write(path, buffer.string)
end

# The latest end-of-life Ruby version.
MINIMUM_RUBY_VERSION = ::Gem::Requirement.new(">= 3.3")

# Rewrite the specified gemspec.
# @param
def update(path: default_gemspec_path, output: $stdout)
	spec = ::Gem::Specification.load(path)
	
	root = File.dirname(path)
	version_path = version_path(root, spec.name)
	
	constant = File.read(File.join(root, version_path))
		.scan(/(?:class|module)\s+(.*?)$/)
		.flatten
		.join("::")
	
	normalize_homepage(spec)
	
	update_metadata(spec)
	
	spec.authors = sorted_authors(root)
	
	spec.metadata.delete_if{|_, value| value.nil?}
	
	output.puts "# frozen_string_literal: true"
	output.puts
	output.puts "require_relative #{version_path.sub(/\.rb$/, '').inspect}"
	output.puts
	output.puts "Gem::Specification.new do |spec|"
	output.puts "\tspec.name = #{spec.name.dump}"
	output.puts "\tspec.version = #{constant}::VERSION"
	output.puts "\t"
	output.puts "\tspec.summary = #{spec.summary.inspect}"
	output.puts "\tspec.authors = #{spec.authors.inspect}"
	output.puts "\tspec.license = #{spec.license.inspect}"
	
	certificate_path = File.expand_path("release.cert", root)
	
	if File.exist?(certificate_path)
		output.puts "\t"
		output.puts "\tspec.cert_chain  = [\"release.cert\"]"
		if spec.signing_key
			output.puts "\tspec.signing_key = #{Bake::Modernize::Signing.private_key_expression(spec.signing_key)}"
		else
			key_path = Bake::Modernize::Signing.private_key_path(root)
			output.puts "\tspec.signing_key = #{Bake::Modernize::Signing.private_key_expression(key_path)}"
		end
	end
	
	if spec.homepage and !spec.homepage.empty?
		output.puts "\t"
		output.puts "\tspec.homepage = #{spec.homepage.inspect}"
	end
	
	if spec.metadata.any?
		output.puts "\t"
		output.puts "\tspec.metadata = {"
		spec.metadata.sort.each do |key, value|
			output.puts "\t\t#{key.inspect} => #{value.inspect},"
		end
		output.puts "\t}"
	end
	
	output.puts "\t"
	output.puts "\tspec.files = #{directory_glob_for(spec)}"
	
	if spec.require_paths != ["lib"]
		output.puts "\tspec.require_paths = [\"lib\"]"
	end
	
	if executables = spec.executables and executables.any?
		output.puts "\t"
		output.puts "\tspec.executables = #{executables.inspect}"
	end
	
	if extensions = spec.extensions and extensions.any?
		output.puts "\t"
		output.puts "\tspec.extensions = #{extensions.inspect}"
	end
	
	# Update the required Ruby version:
	output.puts "\t"
	output.puts "\tspec.required_ruby_version = #{MINIMUM_RUBY_VERSION.to_s.dump}"
	
	# Update the required Rubygems version:
	if spec.runtime_dependencies.any?
		output.puts "\t"
		spec.runtime_dependencies.sort.each do |dependency|
			output.puts "\tspec.add_dependency #{format_dependency(dependency)}"
		end
	end
	
	# Try to move development dependencies to `gems.rb`:
	if spec.development_dependencies.any?
		unless move_development_dependencies(spec.development_dependencies, root)
			output.puts "\t"
			spec.development_dependencies.sort.each do |dependency|
				output.puts "\tspec.add_development_dependency #{format_dependency(dependency)}"
			end
		end
	end
	
	output.puts "end"
end

private

def directory_glob_for(spec, paths = spec.files)
	directories = {}
	root = File.dirname(spec.loaded_from)
	dotfiles = false
	
	paths.each do |path|
		directory, _ = path.split(File::SEPARATOR, 2)
		basename = File.basename(path)
		
		full_path = File.expand_path(directory, root)
		
		if File.directory?(full_path)
			directories[directory] = true
		end
		
		if basename.start_with?(".")
			dotfiles = true
		end
	end
	
	if dotfiles
		return "Dir.glob([\"{#{directories.keys.join(',')}}/**/*\", \"*.md\"], File::FNM_DOTMATCH, base: __dir__)"
	else
		return "Dir[\"{#{directories.keys.join(',')}}/**/*\", \"*.md\", base: __dir__]"
	end
end

def format_dependency(dependency)
	requirements = dependency.requirements_list
	
	if requirements.size == 1
		requirements = requirements.first
	end
	
	if requirements == ">= 0"
		requirements = nil
	end
	
	if dependency.name == "bundler"
		requirements = nil
	end
	
	if requirements
		"#{dependency.name.inspect}, #{requirements.inspect}"
	else
		"#{dependency.name.inspect}"
	end
end

def default_gemspec_path
	Dir["*.gemspec"].first
end

def version_path(root, gem_name)
	candidates = Dir["lib/**/version.rb", base: root]
	
	# If only one version file exists, use it:
	return candidates.first if candidates.size == 1
	
	# Try to match the gem name convention (e.g., "protocol-rack" -> "lib/protocol/rack/version.rb"):
	expected_path = "lib/#{gem_name.gsub('-', '/')}/version.rb"
	return expected_path if candidates.include?(expected_path)
	
	# Fall back to the shortest path (most likely to be the main gem version):
	return candidates.min_by(&:length)
end

require "async"
require "async/http/internet"

def valid_uri?(uri)
	Sync do
		internet = Async::HTTP::Internet.new
		response = internet.head(uri)
		response.close
		
		response.success?
	end
end

GITHUB_PROJECT = /github.com\/(?<account>.*?)\/(?<project>.*?)(\/|\Z)/

def update_metadata(spec)
	spec.metadata["bug_tracker_uri"] ||= detect_bug_tracker_uri(spec)
	spec.metadata["changelog_uri"] ||= detect_changelog_uri(spec)
	spec.metadata["documentation_uri"] ||= detect_documentation_uri(spec)
	spec.metadata["funding_uri"] ||= detect_funding_uri(spec)
	spec.metadata["source_code_uri"] ||= detect_source_code_uri(spec)
end

def normalize_homepage(spec)
	if homepage = spec.homepage
		spec.homepage = homepage.chomp("/")
	end
end

def github_project(spec)
	if homepage = spec.homepage
		homepage.match(GITHUB_PROJECT)
	end
end

def detect_bug_tracker_uri(spec)
	if match = github_project(spec)
		account = match[:account]
		project = match[:project]
		
		return "https://github.com/#{account}/#{project}/issues"
	end
end

def detect_changelog_uri(spec)
	if match = github_project(spec)
		account = match[:account]
		project = match[:project]
		root = File.dirname(spec.loaded_from)
		
		if File.exist?(File.expand_path("releases.md", root))
			branch = Bake::Modernize::Git.current_branch(root, default: "main")
			
			return "https://github.com/#{account}/#{project}/blob/#{branch}/releases.md"
		end
	end
end

def detect_funding_uri(spec)
	if match = github_project(spec)
		account = match[:account]
		
		funding_uri = "https://github.com/sponsors/#{account}/"
		
		if valid_uri?(funding_uri)
			return funding_uri
		end
	end
end

def detect_documentation_uri(spec)
	if match = github_project(spec)
		account = match[:account]
		project = match[:project]
		
		documentation_uri = "https://#{account}.github.io/#{project}/"
		
		if valid_uri?(documentation_uri)
			return documentation_uri
		end
	end
end

def detect_source_code_uri(spec)
	if match = github_project(spec)
		account = match[:account]
		project = match[:project]
		
		return "https://github.com/#{account}/#{project}.git"
	end
end

def sorted_authors(root)
	authorship = Bake::Modernize::License::Authorship.new
	authorship.extract(root)
	
	return authorship.sorted_authors
end

IGNORE_GEMS = %w[
	bundler
].freeze

def move_development_dependencies(dependencies, root = Dir.pwd)
	gemfile_path = File.expand_path("gems.rb", root)
	
	if File.exist?(gemfile_path)
		File.open(gemfile_path, "a") do |file|
			file.puts
			file.puts "# Moved Development Dependencies"
			
			dependencies.each do |dependency|
				next if IGNORE_GEMS.include?(dependency.name)
				
				file.puts "gem #{format_dependency(dependency)}"
			end
		end
		
		true
	end
end
