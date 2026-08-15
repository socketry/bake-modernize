# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2026, by Samuel Williams.

require "bake/modernize"
require "rugged"
require "markly"
require "build/files/system"

def actions(root: Dir.pwd)
	update(root: root)
end

def update(root:)
	travis_path = File.expand_path(".travis.yml", root)
	
	if File.exist?(travis_path)
		FileUtils.rm_rf(travis_path)
	end
	
	update_filenames(root)
	
	template_root = Bake::Modernize.template_path_for("actions")
	Bake::Modernize.copy_template(template_root + ".github", File.join(root, ".github"))
	update_external_test(root)
	
	readme_path = ["README.md", "readme.md"].find{|path| File.exist?(File.expand_path(path, root))}
	
	if readme_path
		update_badges(readme_path, repository_url(root))
	end
	
	system("bundle", "add", "--group", "documentation", "decode", chdir: root)
end

private

def update_filenames(root)
	actions_root = Build::Files::Path.new(root) + ".github/workflows"
	yml_files = actions_root.glob("*.yml")
	
	# Move all .yml files to .yaml files :)
	yml_files.each do |path|
		new_path = path.with(extension: ".yaml", basename: true)
		FileUtils::Verbose.mv(path, new_path)
	end
	
	# Move development.yaml to test.yaml
	development_path = actions_root + "development.yaml"
	test_path = actions_root + "test.yaml"
	if development_path.exist?
		FileUtils::Verbose.mv(development_path, test_path)
	end
	
	# Move coverage.yaml to test-coverage.yaml
	coverage_path = actions_root + "coverage.yaml"
	test_coverage_path = actions_root + "test-coverage.yaml"
	if coverage_path.exist?
		FileUtils::Verbose.mv(coverage_path, test_coverage_path)
	end
end

def update_external_test(root)
	external_config_path = File.expand_path("config/external.yaml", root)
	external_workflow_path = File.expand_path(".github/workflows/test-external.yaml", root)
	
	if File.exist?(external_config_path)
		update_external_test_gem(root, include: true)
	else
		FileUtils::Verbose.rm(external_workflow_path) if File.exist?(external_workflow_path)
		update_external_test_gem(root, include: false)
	end
end

def update_external_test_gem(root, include:)
	gems_path = File.expand_path("gems.rb", root)
	
	return unless File.exist?(gems_path)
	
	if include
		Bake::Modernize::Gems.ensure_dependency(gems_path, "bake-test-external", group: :test, template: external_test_gem_template)
	else
		Bake::Modernize::Gems.remove(gems_path, "bake-test-external")
	end
end

def external_test_gem_template
	File.read(Bake::Modernize.template_path_for("actions") + "gems.rb")
end

def repository_url(root)
	repository = Rugged::Repository.discover(root)
	git_url = repository.remotes["origin"].url
	
	if match = git_url.match(/@(?<url>.*?):(?<path>.*?)(\.git)?\z/)
		return "https://#{match[:url]}/#{match[:path]}"
	end
end

def badge_for(repository_url)
	"[![Development Status](#{repository_url}/workflows/Test/badge.svg)](#{repository_url}/actions?workflow=Test)"
end

def badge?(node)
	return false unless node.type == :link
	return node.all?{|child| child.type == :image}
end

def badges?(node)
	node.any?{|child| badge?(child)}
end

def update_badges(readme_path, repository_url)
	root = Markly.parse(File.read(readme_path))
	
	node = root.first_child
	
	# Skip heading:
	node = node.next if node.type == :header
	
	replacement = Markly.parse(badge_for(repository_url))
	
	# We are looking for the first paragraph which contains only links, which contain one image.
	while node
		if badges?(node)
			node = node.replace(replacement.first_child)
			break
		elsif node.type == :header
			node.insert_before(replacement.first_child)
			break
		end
		
		node = node.next
	end
	
	File.write(readme_path, root.to_markdown(width: 0))
end
