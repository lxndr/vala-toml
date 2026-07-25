# vala-toml

Vala library for TOML 1.1: parse into a DOM, mutate values and structure, and emit valid TOML.

## Dependencies

- `vala`
- `meson` (>= 1.0.0)
- `glib` (GLib / GObject / GIO)
- `gee-0.8`
- `go` (optional, for installing `toml-test`)

## Build

```bash
meson setup build
meson compile -C build
```

## Use as Meson subproject

Create `subprojects/vala-toml.wrap` in your project (the filename must match the Meson project name):

```ini
[wrap-git]
url = https://github.com/lxndr/vala-toml.git
revision = main
depth = 1

[provide]
dependency_names = vala-toml
```

Pin `revision` to a tag or commit hash for reproducible builds. Meson fetches the source on configure; update with `meson subprojects update vala-toml`.

In the parent `meson.build`:

```meson
vala_toml_dep = dependency('vala-toml', fallback: ['vala-toml', 'vala_toml_dep'])

executable(
  'my-app',
  'main.vala',
  dependencies: [vala_toml_dep],
  vala_args: ['--pkg', 'gee-0.8'],
)
```

This links a **static** library built inside the parent's build tree. There is no system install, `.pc` file, or hand-managed `.vapi` — Meson wires the generated VAPI through `vala_toml_dep`.

## Test

```bash
meson test -C build --print-errorlogs
```

## toml-test (TOML 1.1)

Pinned runner: **toml-test v2.2.0** (`github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0`).

Install the pinned binary into `build/tools`, build tools, then run the suite:

```bash
mkdir -p build/tools
GOBIN="$PWD/build/tools" go install github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0
meson compile -C build
./build/tools/toml-test test -toml=1.1 \
  -decoder="$PWD/build/tools/vala-toml-decoder" \
  -encoder="$PWD/build/tools/vala-toml-encoder"
```

Or use the helper (installs the pinned `toml-test` if missing, then runs decoder + encoder for TOML 1.1):

```bash
./scripts/run-toml-test.sh
```

## Minimal API

```vala
var table = Toml.parse_string ("a = 1\n");
table.get ("a"); // Value
table.style.inline = false;
stdout.printf ("%s", Toml.write_string (table));
```
