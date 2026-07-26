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
assert (((Toml.Integer) table.get (Toml.Key.from_str ("a"))).value == 1);

table.set (Toml.Key.from_str ("a"), new Toml.Integer (2));
table.set (Toml.Key.from_str ("name"), new Toml.String.from_str ("hi"));
stdout.printf ("%s", Toml.write_string (table));
```

Nested tables and arrays:

```vala
var root = new Toml.Table ();
var child = new Toml.Table ();
child.set (Toml.Key.from_str ("x"), new Toml.Integer (9));
root.set (Toml.Key.from_str ("child"), child);

var nums = new Toml.Array ();
nums.add (new Toml.Integer (1));
nums.add (new Toml.Integer (2));
root.set (Toml.Key.from_str ("nums"), nums);

assert (((Toml.Integer) ((Toml.Table) root.get (Toml.Key.from_str ("child"))).get (Toml.Key.from_str ("x"))).value == 9);
assert (((Toml.Integer) ((Toml.Array) root.get (Toml.Key.from_str ("nums"))).get (0)).value == 1);
stdout.printf ("%s", Toml.write_string (root));
```

Style hints for emission:

```vala
var root = new Toml.Table ();

var point = new Toml.Table ();
point.style.inline = true;
point.set (Toml.Key.from_str ("x"), new Toml.Integer (1));
point.set (Toml.Key.from_str ("y"), new Toml.Integer (2));
root.set (Toml.Key.from_str ("point"), point);

var nums = new Toml.Array ();
nums.style.multiline = true;
nums.add (new Toml.Integer (1));
nums.add (new Toml.Integer (2));
root.set (Toml.Key.from_str ("nums"), nums);

var nested = new Toml.Table ();
nested.style.dotted_keys = true;
nested.set (Toml.Key.from_str ("leaf"), new Toml.Integer (1));
root.set (Toml.Key.from_str ("path"), nested);

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

`Key` and `String` store payload in `GLib.Bytes`. `to_string()` on
either truncates at the first NUL; use `.bytes` when embedded NUL may be
present. `write_string` rejects invalid UTF-8 in keys and strings.
`Key` exposes `hash()` and `equal_to()` for map lookups; internally
`Table` uses `Gee.HashMap<Key?, Value>` with explicit hash and
equality delegates (Vala 0.56 cannot declare `Gee.Hashable` on a struct).

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

    public abstract class Value {
    }

    public struct Key {
        public Key (Bytes bytes);
        public Key.from_str (string s);
        public Bytes bytes { get; }
        public string to_string ();
        public uint hash ();
        public bool equal_to (Key other);
    }

    public class String : Value {
        public String (Bytes bytes);
        public String.from_str (string s);
        public Bytes bytes { get; }
        public string to_string ();
    }

    public class Integer : Value {
        public Integer (int64 value);
        public int64 value { get; }
    }

    public class Float : Value {
        public Float (double value);
        public double value { get; }
    }

    public class Boolean : Value {
        public Boolean (bool value);
        public bool value { get; }
    }

    public class OffsetDateTime : Value {
        public OffsetDateTime (DateTime dt) throws ValueError;
        public DateTime value { get; }
    }

    public class LocalDate : Value {
        public LocalDate (Date d) throws ValueError;
        public Date value { get; }
    }

    public class LocalTime : Value {
        public LocalTime (int hour, int minute, int second, int microsecond = 0) throws ValueError;
        public int hour { get; private set; }
        public int minute { get; private set; }
        public int second { get; private set; }
        public int microsecond { get; private set; }
    }

    public class LocalDateTime : Value {
        public LocalDateTime (Date date, LocalTime time) throws ValueError;
        public Date date { get; private set; }
        public LocalTime time { get; private set; }
    }

    public class Table : Value {
        public Table ();
        public TableStyle style;
        public int size { get; }
        public Gee.List<Key?> keys { owned get; }
        public new void set (Key key, Value value) throws ValueError;
        public new Value? get (Key key);
        public bool unset (Key key);
        public bool has (Key key);
    }

    public class Array : Value {
        public Array ();
        public ArrayStyle style;
        public int size { get; }
        public Gee.Iterator<Value> iterator ();
        public void add (Value value) throws ValueError;
        public new Value get (int index);
        public new void set (int index, Value value) throws ValueError;
    }

    public struct TableStyle {
        public TableStyle ();
        public bool inline;
        public bool dotted_keys;
        public bool multiline;
        public int indent;
    }

    public struct ArrayStyle {
        public ArrayStyle ();
        public bool inline;
        public bool multiline;
        public int indent;
    }

    public struct WriteOptions {
        public WriteOptions ();
        public int indent;
    }
}
```

`ParseError.FAILED` — invalid UTF-8 or invalid TOML.
`WriteError.FAILED` — emission failure (including invalid UTF-8 in keys or strings).
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
