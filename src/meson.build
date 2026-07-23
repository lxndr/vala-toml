vala_toml_sources = files(
  'toml.vala',
  'toml-error.vala',
  'toml-style.vala',
  'toml-value.vala',
  'toml-table.vala',
  'toml-array.vala',
  'toml-equal.vala',
  'toml-token.vala',
  'toml-lexer.vala',
  'toml-parser.vala',
  'toml-writer.vala',
  'toml-json.vala',
)

vala_toml_lib = static_library(
  'vala-toml',
  vala_toml_sources,
  dependencies: vala_toml_deps,
  vala_args: ['--pkg', 'gee-0.8'],
  install: false,
)

vala_toml_dep = declare_dependency(
  link_with: vala_toml_lib,
  dependencies: vala_toml_deps,
  include_directories: include_directories('.'),
)
