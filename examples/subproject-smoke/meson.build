project(
  'vala-toml-subproject-smoke',
  ['vala', 'c'],
  version: '0.0.0',
  meson_version: '>= 1.0.0',
)

gee_dep = dependency('gee-0.8')
vala_toml_dep = dependency('vala-toml', fallback: ['vala-toml', 'vala_toml_dep'])

executable(
  'smoke',
  'main.vala',
  dependencies: [vala_toml_dep, gee_dep],
  vala_args: ['--pkg', 'gee-0.8'],
)
