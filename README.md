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

## API reference

Namespace `Toml`. Examples above omit `try`/`catch`; callers must handle
`ParseError`, `WriteError`, and `ValueError` where thrown.

`parse_string` rejects invalid UTF-8 with `ParseError`. Bare carriage
returns and disallowed control characters are rejected during lexing.
Bytes and streams are the caller’s responsibility — convert to/from
`string` yourself. Lexer, parser, writer, and tagged-JSON helpers are
internal. Fuller gtk-doc comments live under `src/`.

```vala
namespace Toml {
    public Table parse_string (string text) throws ParseError;
    public string write_string (Table root, WriteOptions? options = null) throws WriteError;
    public bool values_equal (Value? a, Value? b);

    public errordomain ParseError {
        FAILED
    }

    public errordomain WriteError {
        FAILED
    }

    public errordomain ValueError {
        INVALID
    }

    public enum ValueKind {
        STRING,
        INTEGER,
        FLOAT,
        BOOLEAN,
        OFFSET_DATETIME,
        LOCAL_DATETIME,
        LOCAL_DATE,
        LOCAL_TIME,
        TABLE,
        ARRAY
    }

    public class Value {
        public ValueKind kind { get; protected set; }

        public static Value from_string (string v);
        public static Value from_string_bytes (uint8[] bytes);
        public static Value from_integer (int64 v);
        public static Value from_float (double v);
        public static Value from_boolean (bool v);
        public static Value from_offset_datetime (DateTime dt) throws ValueError;
        public static Value from_local_datetime (LocalDateTime v) throws ValueError;
        public static Value from_local_date (Date d) throws ValueError;
        public static Value from_local_time (LocalTime t) throws ValueError;

        public string? get_string ();
        public uint8[]? get_string_bytes ();
        public int64? get_integer ();
        public double? get_float ();
        public bool? get_boolean ();
        public DateTime? get_offset_datetime ();
        public LocalDateTime? get_local_datetime ();
        public Date? get_local_date ();
        public LocalTime? get_local_time ();
        public virtual Table? as_table ();
        public virtual Array? as_array ();
    }

    public class Table : Value {
        public TableStyle style;
        public int size { get; }
        public Gee.List<string> keys { owned get; }

        public Table ();
        public new void set (string key, Value value) throws ValueError;
        public void set_bytes (uint8[] key_bytes, Value value) throws ValueError;
        public new Value? get (string key);
        public Value? get_bytes (uint8[] key_bytes);
        public bool unset (string key);
        public bool has (string key);
        public bool has_bytes (uint8[] key_bytes);
        public override Table? as_table ();
    }

    public class Array : Value {
        public ArrayStyle style;
        public int size { get; }

        public Array ();
        public Gee.Iterator<Value> iterator ();
        public void add (Value value) throws ValueError;
        public new Value get (int index);
        public new void set (int index, Value value) throws ValueError;
        public override Array? as_array ();
    }

    public class LocalTime {
        public int hour { get; private set; }
        public int minute { get; private set; }
        public int second { get; private set; }
        public int microsecond { get; private set; }

        public LocalTime (int hour, int minute, int second, int microsecond = 0) throws ValueError;
    }

    public class LocalDateTime {
        public Date date { get; private set; }
        public LocalTime time { get; private set; }

        public LocalDateTime (Date date, LocalTime time) throws ValueError;
    }

    public struct TableStyle {
        public bool inline;
        public bool dotted_keys;
        public bool multiline;
        public int indent;

        public TableStyle ();
    }

    public struct ArrayStyle {
        public bool inline;
        public bool multiline;
        public int indent;

        public ArrayStyle ();
    }

    public struct WriteOptions {
        public int indent;

        public WriteOptions ();
    }
}
```

`ParseError.FAILED` — invalid UTF-8 or invalid TOML.
`WriteError.FAILED` — emission failure.
`ValueError.INVALID` — invalid arguments when constructing a typed value.

`TableStyle.indent` / `ArrayStyle.indent`: negative means use `WriteOptions.indent` (default 2).
`LocalTime` / `LocalDateTime` have no timezone; offset date-times use `GLib.DateTime`.

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
