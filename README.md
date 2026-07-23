# vala-toml

Vala library for TOML 1.1 manipulation: parse into a DOM, mutate values and structure, and emit valid TOML.

## Dependencies

- Vala
- Meson (>= 1.0.0)
- GLib 2.0, GObject, GIO
- libgee-0.8
- json-glib-1.0

## Build

```bash
meson setup build
meson compile -C build
```

## Test

```bash
meson test -C build --print-errorlogs
```

## toml-test smoke

Decoder (TOML stdin → tagged JSON) and encoder (tagged JSON stdin → TOML):

```bash
echo 'a = 1' | ./build/tools/vala-toml-decoder
echo '{"a":{"type":"integer","value":"1"}}' | ./build/tools/vala-toml-encoder
```
