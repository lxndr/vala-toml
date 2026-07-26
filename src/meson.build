vala_toml_sources = files(
  'toml.vala',
  'toml-error.vala',
  'toml-key.vala',
  'toml-value.vala',
  'toml-string.vala',
  'toml-integer.vala',
  'toml-float.vala',
  'toml-boolean.vala',
  'toml-local-date.vala',
  'toml-local-time.vala',
  'toml-local-datetime.vala',
  'toml-offset-datetime.vala',
  'toml-parser-datetime.vala',
  'toml-format-datetime.vala',
  'toml-table.vala',
  'toml-array.vala',
  'toml-equal.vala',
  'toml-token.vala',
  'toml-lexer.vala',
  'toml-parser.vala',
  'toml-writer.vala',
  'toml-json.vala',
)

# Filenames must be basename-only so valac pairs internal header correctly.
vala_toml_lib = static_library(
  'vala-toml',
  vala_toml_sources,
  dependencies: vala_toml_deps,
  vala_header: 'vala-toml.h',
  vala_vapi: 'vala-toml.vapi',
  vala_args: [
    '--pkg', 'gee-0.8',
    '--internal-vapi=vala-toml-internal.vapi',
    '--internal-header=vala-toml-internal.h',
  ],
  install: false,
)

vala_toml_dep = declare_dependency(
  link_with: vala_toml_lib,
  dependencies: vala_toml_deps,
  include_directories: include_directories('.'),
)

# Stage internal VAPI/header to a stable build path for dependents.
# After the first compile, confirm source paths with:
#   find build -name 'vala-toml-internal.vapi' -o -name 'vala-toml-internal.h'
# Adjust the `cp` inputs if Meson placed them under libvala-toml.a.p/ instead.
vala_toml_internal_stage = custom_target(
  'vala-toml-internal-stage',
  output: ['vala-toml-internal.vapi', 'vala-toml-internal.h'],
  command: [
    find_program('cp'),
    '@0@/libvala-toml.a.p/vala-toml-internal.vapi'.format(meson.current_build_dir()),
    '@0@/vala-toml-internal.h'.format(meson.project_build_root()),
    '@OUTDIR@',
  ],
  depends: vala_toml_lib,
)

# Link the archive without injecting the public .vapi.
vala_toml_internal_dep = declare_dependency(
  link_args: [
    '-L' + meson.current_build_dir(),
    '-lvala-toml',
  ],
  include_directories: include_directories('.'),
  dependencies: vala_toml_deps,
  sources: [vala_toml_internal_stage[0]],
)
