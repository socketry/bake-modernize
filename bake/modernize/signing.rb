# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2026, by Samuel Williams.

require "bake/modernize"

def signing(root: Dir.pwd)
	update(root: root)
end

def update(root:)
	signing = Bake::Modernize::Signing.load(root)
	certificate_path = File.expand_path("release.cert", root)
	
	if signing.certificate_path
		FileUtils.cp(signing.certificate_path, certificate_path)
	end
end
