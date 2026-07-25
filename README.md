# vala-toml

Vala library for TOML 1.1: parse into a DOM, mutate values and structure, and emit valid TOML.

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

## Usage

Parse, read, mutate, and write:

```vala
var table = Toml.parse_string ("a = 1\n");
assert (table.get ("a").get_integer () == 1);

table.set ("a", Toml.Value.from_integer (2));
table.set ("name", Toml.Value.from_string ("hi"));
stdout.printf ("%s", Toml.write_string (table));
```

Nested tables and arrays:

```vala
var root = new Toml.Table ();
var child = new Toml.Table ();
child.set ("x", Toml.Value.from_integer (9));
root.set ("child", child);

var nums = new Toml.Array ();
nums.add (Toml.Value.from_integer (1));
nums.add (Toml.Value.from_integer (2));
root.set ("nums", nums);

assert (root.get ("child").as_table ().get ("x").get_integer () == 9);
assert (root.get ("nums").as_array ().get (0).get_integer () == 1);
stdout.printf ("%s", Toml.write_string (root));
```

Style hints for emission:

```vala
var root = new Toml.Table ();

var point = new Toml.Table ();
point.style.inline = true;
point.set ("x", Toml.Value.from_integer (1));
point.set ("y", Toml.Value.from_integer (2));
root.set ("point", point);

var nums = new Toml.Array ();
nums.style.multiline = true;
nums.add (Toml.Value.from_integer (1));
nums.add (Toml.Value.from_integer (2));
root.set ("nums", nums);

var nested = new Toml.Table ();
nested.style.dotted_keys = true;
nested.set ("leaf", Toml.Value.from_integer (1));
root.set ("path", nested);

stdout.printf ("%s", Toml.write_string (root));
```

## API overview

Namespace: `Toml`. Callers must handle `ParseError` / `WriteError` where thrown, and `ValueError` from typed datetime constructors; examples above omit `try`/`catch`. Fuller descriptions are in gtk-doc comments under `src/`. Lexer, parser, and tagged-JSON helpers are internal.

### Entry points

- `parse_string (string text)` → `Table` — parse UTF-8 TOML text
- `parse_bytes (uint8[] data)` → `Table` — parse UTF-8 bytes
- `parse (InputStream stream)` → `Table` — read stream and parse
- `write_string (Table root, WriteOptions? options = null)` → `string` — serialize to TOML text
- `write (Table root, OutputStream stream, WriteOptions? options = null)` — serialize to a stream

### Errors

- `ParseError.FAILED` — invalid TOML or parse I/O failure
- `WriteError.FAILED` — emission or write I/O failure
- `ValueError.INVALID` — invalid arguments when constructing a typed value

### ValueKind

`STRING`, `INTEGER`, `FLOAT`, `BOOLEAN`, `OFFSET_DATETIME`, `LOCAL_DATETIME`, `LOCAL_DATE`, `LOCAL_TIME`, `TABLE`, `ARRAY`

### Value

- `kind` — runtime `ValueKind`
- `from_string` / `from_string_bytes` — string value
- `from_integer` / `from_float` / `from_boolean` — scalar values
- `from_offset_datetime` / `get_offset_datetime` — offset date-time as `GLib.DateTime`
- `from_local_datetime` / `get_local_datetime` — local date-time as `Toml.LocalDateTime`
- `from_local_date` / `get_local_date` — local date as `GLib.Date`
- `from_local_time` / `get_local_time` — local time as `Toml.LocalTime`
- `get_string` / `get_string_bytes` — string payload or null
- `get_integer` / `get_float` / `get_boolean` — typed payload or null
- `as_table` / `as_array` — downcast or null

`LocalTime` stores validated hour, minute, second, and microsecond fields without a timezone. `LocalDateTime` combines a valid `GLib.Date` with a `LocalTime`, also without a timezone.

### Table

- `Table ()` — empty table; `style` (`TableStyle`); `size`; `keys` (insertion order)
- `set` / `set_bytes` — set key
- `get` / `get_bytes` — get value or null
- `unset` — remove key; `has` / `has_bytes` — key presence

### Array

- `Array ()` — empty array; `style` (`ArrayStyle`); `size`; `iterator ()`
- `add` — append; `get` / `set` — element by index

### Styles

- `TableStyle` — `inline`, `dotted_keys`, `multiline`, `indent` (−1 = use `WriteOptions.indent`)
- `ArrayStyle` — `inline`, `multiline`, `indent` (−1 = use `WriteOptions.indent`)
- `WriteOptions` — `indent` (default 2)

### Equality

- `values_equal (Value? a, Value? b)` — deep structural equality

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

## Test

```bash
meson test -C build --print-errorlogs
```

### toml-test (TOML 1.1)

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
