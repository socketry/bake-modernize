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
	
	update_workflows(root)
	update_external_test(root)
	
	readme_path = ["README.md", "readme.md"].find{|path| File.exist?(File.expand_path(path, root))}
	
	if readme_path
		update_badges(readme_path, repository_url(root))
	end
	
	system("bundle", "add", "--group", "documentation", "decode", chdir: root)
end

private

OPTIONAL_TEST_RUBIES = ["truffleruby", "jruby"].freeze

def update_workflows(root)
	template_root = Bake::Modernize.template_path_for("actions")
	test_workflow_path = File.expand_path(".github/workflows/test.yaml", root)
	merge_test_workflow = File.exist?(test_workflow_path)
	
	if merge_test_workflow
		copy_actions_template(template_root + ".github", File.join(root, ".github"), except: "workflows/test.yaml")
		update_test_workflow(test_workflow_path)
	else
		Bake::Modernize.copy_template(template_root + ".github", File.join(root, ".github"))
	end
end

def copy_actions_template(source_path, destination_path, except:)
	glob = Build::Files::Glob.new(source_path, "**/*")
	
	glob.each do |path|
		next if path.relative_path == except
		
		full_path = File.join(destination_path, path.relative_path)
		
		if File.directory?(path)
			FileUtils.mkdir_p(full_path) unless File.directory?(full_path)
		elsif Bake::Modernize.stale?(path, full_path)
			FileUtils::Verbose.cp(path, full_path)
		end
	end
end

def update_test_workflow(path)
	require "async/ollama"
	
	existing = File.read(path)
	updated = Async::Ollama::Transform.call(existing,
		model: "qwen3-coder:latest",
		instruction: test_workflow_instruction(existing),
		template: test_workflow_template(existing),
	)
	
	unless test_workflow_valid?(updated, existing)
		raise ArgumentError, "Test workflow transform output did not satisfy validation!"
	end
	
	File.write(path, updated)
end

def test_workflow_instruction(existing)
	optional_rubies = OPTIONAL_TEST_RUBIES.select{|ruby| test_workflow_ruby?(existing, ruby)}
	removed_rubies = OPTIONAL_TEST_RUBIES - optional_rubies
	
	<<~TEXT
		Update the GitHub Actions test workflow to match the supplied template while preserving project-specific configuration.
		Preserve existing services, env, custom matrix dimensions, matrix excludes, matrix includes, steps, comments and formatting unless they conflict with the template.
		Preserve these existing optional Ruby matrix entries if present: #{optional_rubies.join(", ")}.
		Do not add these optional Ruby matrix entries because they are absent from the existing workflow: #{removed_rubies.join(", ")}.
		Keep `ruby: head` as an experimental Ubuntu matrix include.
		Use `actions/checkout@v7`, `ruby/setup-ruby@v1`, `bundler-cache: true`, and `bundle exec bake test`.
	TEXT
end

def test_workflow_template(existing)
	template = File.read(Bake::Modernize.template_path_for("actions") + ".github/workflows/test.yaml")
	entries = OPTIONAL_TEST_RUBIES.select{|ruby| test_workflow_ruby?(existing, ruby)}.map do |ruby|
		"          - os: ubuntu\n            ruby: #{ruby}\n            experimental: true\n"
	end.join
	
	template.sub(/^          - os: ubuntu\n            ruby: head\n/m, entries + "          - os: ubuntu\n            ruby: head\n")
end

def test_workflow_valid?(updated, existing)
	optional_rubies_preserved = OPTIONAL_TEST_RUBIES.all? do |ruby|
		test_workflow_ruby?(updated, ruby) == test_workflow_ruby?(existing, ruby)
	end
	
	return false unless optional_rubies_preserved
	return false if existing.include?("services:") && !updated.include?("services:")
	return false if existing.include?("env:") && !updated.include?("env:")
	
	return updated.include?("ruby/setup-ruby@v1") && updated.include?("bundle exec bake test")
end

def test_workflow_ruby?(content, ruby)
	content.match?(/^\s*ruby:\s*["']?#{Regexp.escape(ruby)}["']?\s*$/)
end

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
	
	require "async/ollama"
	
	existing = File.read(gems_path)
	updated = Async::Ollama::Transform.call(existing,
		model: "qwen3-coder:latest",
		instruction: external_test_gem_instruction(include),
		template: external_test_gem_template(include),
	)
	File.write(gems_path, updated)
end

def external_test_gem_instruction(include)
	if include
		"Ensure the `bake-test-external` gem is included in the `test` group. Preserve existing gems, groups, options, comments and formatting. If the `test` group does not exist, create one. Do not duplicate the gem if it already exists."
	else
		"Remove the `bake-test-external` gem from the file. Preserve existing gems, groups, options, comments and formatting. Remove empty lines only when they were only separating the removed gem."
	end
end

def external_test_gem_template(include)
	template = File.read(Bake::Modernize.template_path_for("actions") + "gems.rb")
	
	if include
		return template
	end
	
	template.sub(/^\s*gem "bake-test-external"\n/, "")
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
