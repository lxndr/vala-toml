# vala-toml

Vala library for TOML 1.1 manipulation: parse into a DOM, mutate values and structure, and emit valid TOML.

## Dependencies

- Vala
- Meson (>= 1.0.0)
- GLib 2.0, GObject, GIO
- libgee-0.8
- json-glib-1.0
- Go (optional, for installing `toml-test`)

## Build

```bash
meson setup build
meson compile -C build
```

## Test

```bash
meson test -C build --print-errorlogs
```

## toml-test (TOML 1.1)

Pinned runner: **toml-test v2.2.0** (`github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0`).

Install the pinned binary into `build/tools`:

```bash
mkdir -p build/tools
GOBIN="$PWD/build/tools" go install github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0
meson compile -C build
```

Run the full decoder + encoder suite for TOML 1.1:

```bash
./build/tools/toml-test test -toml=1.1 \
  -decoder="$PWD/build/tools/vala-toml-decoder" \
  -encoder="$PWD/build/tools/vala-toml-encoder"
```

Or use the helper (installs the pinned `toml-test` if missing, then runs the suite):

```bash
./scripts/run-toml-test.sh
```

Smoke-check the CLIs:

```bash
echo 'a = 1' | ./build/tools/vala-toml-decoder
echo '{"a":{"type":"integer","value":"1"}}' | ./build/tools/vala-toml-encoder
```
