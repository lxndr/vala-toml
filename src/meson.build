vala_toml_sources = files(
  'toml.vala',
  'toml-error.vala',
)

vala_toml_lib = library(
  'vala-toml',
  vala_toml_sources,
  dependencies: vala_toml_deps,
  vala_args: ['--pkg', 'gee-0.8'],
  install: true,
)

vala_toml_dep = declare_dependency(
  link_with: vala_toml_lib,
  dependencies: vala_toml_deps,
  include_directories: include_directories('.'),
)
