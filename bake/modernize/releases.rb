# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "bake/modernize"
require "markly"

# Update the project to use bake-releases for release notes.
#
# @parameter root [String] The root directory of the project.
def releases(root: Dir.pwd)
	update_releases_gem(root)
	
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

def update_releases_gem(root)
	gems_path = File.expand_path("gems.rb", root)
	return unless File.exist?(gems_path)
	
	Bake::Modernize::Gems.ensure_dependency(gems_path,
		"bake-releases",
		group: :maintenance,
		template: File.read(RELEASES_TEMPLATE_ROOT + "gems.rb"),
	)
end

def update_releases_md(releases_md_path)
	# Don't overwrite an existing releases.md:
	return if File.exist?(releases_md_path)
	
	FileUtils.cp(RELEASES_TEMPLATE_ROOT + "releases.md", releases_md_path)
end

def update_bake(root)
	bake_path = File.join(root, "bake.rb")
	template = File.read(RELEASES_TEMPLATE_ROOT + "bake.rb")
	
	if File.exist?(bake_path)
		Bake::Modernize.transform_file(bake_path,
			instruction: "Merge the template into the existing file. Add any missing methods and update existing method bodies to include any missing calls shown in the template. Do not remove any existing calls.",
			template: template,
			validate: -> content{validate_bake_transform(content)},
		)
	else
		File.write(bake_path, template)
	end
end

def validate_bake_transform(content)
	content.include?(%{context["releases:update"].call(version)}) &&
		content.include?(%{context["releases:github:release"].call(tag)})
end
