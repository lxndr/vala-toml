project(
  'vala-toml',
  ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 1.0.0',
  default_options: [
    'warning_level=1',
    'c_std=c11',
  ],
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')
gee_dep = dependency('gee-0.8')

vala_toml_deps = [glib_dep, gobject_dep, gio_dep, gee_dep]

subdir('src')
meson.override_dependency('vala-toml', vala_toml_dep)

if not meson.is_subproject()
  subdir('tests')
  subdir('tools')
endif
