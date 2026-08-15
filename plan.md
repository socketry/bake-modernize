# Plan

1. Convert `modernize:decode` to use `Bake::Modernize.transform_file` with validation.
2. Convert `modernize:releases` `update_bake` to use `Bake::Modernize.transform_file` with validation.
3. Convert `modernize:rubocop` dependency updates to use `Bake::Modernize::Gems` instead of `bundle add`.
4. Convert `modernize:actions` documentation dependency update to use `Bake::Modernize::Gems` instead of `bundle add`.
5. Convert `modernize:releases` dependency update to use `Bake::Modernize::Gems` instead of `bundle add`.
