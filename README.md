# vala-toml

Vala library for TOML 1.1 manipulation: parse into a DOM, mutate values and structure, and emit valid TOML.

## Dependencies

- Vala
- Meson (>= 1.0.0)
- GLib 2.0, GObject, GIO
- libgee-0.8

## Build

```bash
meson setup build
meson compile -C build
```

## Test

```bash
meson test -C build --print-errorlogs
```
