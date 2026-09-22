# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "bake/modernize"
require "markly"
require "erb"

# Update the project to use bake-releases for release notes.
#
# @parameter root [String] The root directory of the project.
def releases(root: Dir.pwd)
	system("bundle", "add", "bake-releases", "--group", "maintenance", chdir: root)
	
	update_releases(File.join(root, "readme.md"))
	update_releases_md(File.join(root, "releases.md"))
	update_bake(root)
end

# Migrate release dependencies and hooks to bake-gem-github. Configure its workflows with gem:github:setup afterwards.
#
# @parameter root [String] The root directory of the project.
def github(root: Dir.pwd)
	require "bundler"
	
	dependencies = Bake::Modernize.gem_dependencies(root)
	environment = Bundler.unbundled_env
	
	unless dependencies.include?("bake-gem-github")
		system(environment, "bundle", "add", "bake-gem-github", "--group", "maintenance", chdir: root, unsetenv_others: true, exception: true)
	end
	
	if dependencies.include?("bake-gem")
		system(environment, "bundle", "remove", "bake-gem", chdir: root, unsetenv_others: true, exception: true)
	end
	
	update_releases(File.join(root, "readme.md"))
	update_releases_md(File.join(root, "releases.md"))
	update_bake(root)
end

private

DEFAULT_CONTRIBUTING = <<~MARKDOWN
## Releases

There are no documented releases.
MARKDOWN

def update_releases(readme_path)
	root = Markly.parse(File.read(readme_path))
	
	return if root.find_header("Releases")
	
	replacement = Markly.parse(DEFAULT_CONTRIBUTING)
	
	unless node = root.find_header("See Also")
		node = root.find_header("Contributing")
	end
	
	if node
		node.append_before(replacement)
	else
		root.last_child.append_after(replacement)
	end
	
	File.write(readme_path, root.to_markdown(width: 0))
end

RELEASES_TEMPLATE_ROOT = Bake::Modernize.template_path_for("releases")

def update_releases_md(releases_md_path)
	# Don't overwrite an existing releases.md:
	return if File.exist?(releases_md_path)
	
	FileUtils.cp(RELEASES_TEMPLATE_ROOT + "releases.md", releases_md_path)
end

def update_bake(root)
	require "async/ollama"
	
	bake_path = File.join(root, "bake.rb")
	github_releases = Bake::Modernize.gem_dependencies(root).include?("bake-gem-github")
	template = ERB.new(File.read(RELEASES_TEMPLATE_ROOT + "bake.rb.erb"), trim_mode: "-").result(binding)
	instruction = "Merge the template into the existing file. Add any missing methods and update existing method bodies to include any missing calls shown in the template."
	
	if github_releases
		instruction += " Remove the releases:github:release call from after_gem_release, because bake-gem-github publishes the GitHub release. Remove that method and its documentation if it becomes empty. Do not add an after_gem_release hook. Preserve all other methods and calls."
	else
		instruction += " Do not remove any existing calls."
	end
	
	if File.exist?(bake_path)
		existing = File.read(bake_path)
		updated = Async::Ollama::Transform.call(existing,
			model: "qwen3-coder:latest",
			instruction: instruction,
			template: template,
		)
		File.write(bake_path, updated)
	else
		File.write(bake_path, template)
	end
end
