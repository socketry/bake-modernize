# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Bake
	module Modernize
		DEFAULT_TRANSFORM_MODEL = "qwen3-coder:latest"
		
		# Transform the given file using an agent, optionally validating the result before writing it back.
		def self.transform_file(path, instruction:, template:, model: DEFAULT_TRANSFORM_MODEL, validate: nil)
			require "async/ollama"
			
			existing = File.read(path)
			updated = Async::Ollama::Transform.call(existing,
				model: model,
				instruction: instruction,
				template: template,
			)
			
			if validate && !validate.call(updated)
				raise ArgumentError, "Transform output did not satisfy validation!"
			end
			
			return false if updated == existing
			
			File.write(path, updated)
			return true
		end
	end
end
