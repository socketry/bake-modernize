# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "bake/modernize"
require "build/files/system"

def rubocop(root: Dir.pwd)
	update(root: root)
end

def update(root:)
	update_rubocop_gems(root)
	
	template_root = Bake::Modernize.template_path_for("rubocop")
	Bake::Modernize.copy_template(template_root + ".github", File.join(root, ".github"))
	FileUtils::Verbose.cp(template_root + ".rubocop.yml", File.join(root, ".rubocop.yml"))
	
	system("bundle", "update", chdir: root)
	system("bundle", "exec", "rubocop", chdir: root)
end

private

def update_rubocop_gems(root)
	gems_path = File.expand_path("gems.rb", root)
	return unless File.exist?(gems_path)
	
	Bake::Modernize::Gems.ensure_dependencies(gems_path,
		["rubocop", "rubocop-md", "rubocop-socketry"],
		group: :test,
		template: File.read(Bake::Modernize.template_path_for("rubocop") + "gems.rb"),
	)
end
