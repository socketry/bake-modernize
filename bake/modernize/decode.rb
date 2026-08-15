# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake/modernize"

DECODE_TEMPLATE_ROOT = Bake::Modernize.template_path_for("decode")

# Move the `decode` gem from the `test` group to the `maintenance` group.
#
# @parameter root [String] The root directory of the project.
def decode(root: Dir.pwd)
	gems_path = File.join(root, "gems.rb")
	
	return unless File.exist?(gems_path)
	
	existing = File.read(gems_path)
	template = File.read(DECODE_TEMPLATE_ROOT + "gems.rb")
	Bake::Modernize.transform_file(gems_path,
		instruction: "Move the `decode` gem from the `test` group to the `maintenance` group. If the `decode` gem is not in a `test` group, leave the file unchanged. If there is no `maintenance` group, create one.",
		template: template,
		validate: -> content{validate_decode_transform(existing, content)},
	)
end

private

def validate_decode_transform(existing, content)
	return true unless Bake::Modernize::Gems.present?(existing, "decode")
	
	Bake::Modernize::Gems.present?(content, "decode")
end
