test_dom = executable(
  'test-dom',
  'test-dom.vala',
  dependencies: vala_toml_dep,
  vala_args: ['--pkg', 'gee-0.8'],
)

test('dom', test_dom)

test_roundtrip = executable(
  'test-roundtrip',
  'test-roundtrip.vala',
  dependencies: vala_toml_dep,
  vala_args: ['--pkg', 'gee-0.8'],
)

test('roundtrip', test_roundtrip)
