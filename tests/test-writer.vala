using Toml;

void test_write_simple () {
    try {
        var t = new Toml.Table ();
        t.set (Key.from_str ("a"), new Integer (1));
        t.set (Key.from_str ("b"), new String.from_str ("x"));
        var s = Toml.write_string (t);
        assert (s.contains ("a = 1"));
        assert (s.contains ("b = \"x\""));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_nested_standard_table () {
    try {
        var root = new Toml.Table ();
        var foo = new Toml.Table ();
        foo.set (Key.from_str ("bar"), new Integer (1));
        root.set (Key.from_str ("foo"), foo);
        var s = Toml.write_string (root);
        assert (s.contains ("[foo]"));
        assert (s.contains ("bar = 1"));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_inline_table () {
    try {
        var root = new Toml.Table ();
        var point = new Toml.Table ();
        point.style.inline = true;
        point.set (Key.from_str ("x"), new Integer (1));
        point.set (Key.from_str ("y"), new Integer (2));
        root.set (Key.from_str ("point"), point);
        assert (Toml.write_string (root) == "point = { x = 1, y = 2 }\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_multiline_inline_table () {
    try {
        var root = new Toml.Table ();
        var point = new Toml.Table ();
        point.style.inline = true;
        point.style.multiline = true;
        point.set (Key.from_str ("x"), new Integer (1));
        point.set (Key.from_str ("y"), new Integer (2));
        root.set (Key.from_str ("point"), point);
        // indent from WriteOptions default (2); no trailing comma
        assert (Toml.write_string (root) == "point = {\n  x = 1,\n  y = 2\n}\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_array_multiline () {
    try {
        var root = new Toml.Table ();
        var nums = new Toml.Array ();
        nums.style.multiline = true;
        nums.add (new Integer (1));
        nums.add (new Integer (2));
        root.set (Key.from_str ("nums"), nums);
        assert (Toml.write_string (root) == "nums = [\n  1,\n  2\n]\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_multiline_indent_override () {
    try {
        var root = new Toml.Table ();
        var nums = new Toml.Array ();
        nums.style.multiline = true;
        nums.style.indent = 4;
        nums.add (new Integer (1));
        root.set (Key.from_str ("nums"), nums);
        assert (Toml.write_string (root) == "nums = [\n    1\n]\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_aot_standard () {
    try {
        var root = new Toml.Table ();
        var products = new Toml.Array ();
        var p1 = new Toml.Table ();
        p1.set (Key.from_str ("name"), new String.from_str ("A"));
        products.add (p1);
        root.set (Key.from_str ("products"), products);
        var s = Toml.write_string (root);
        assert (s == "[[products]]\nname = \"A\"\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_aot_inline () {
    try {
        var root = new Toml.Table ();
        var products = new Toml.Array ();
        products.style.inline = true;
        var p1 = new Toml.Table ();
        p1.style.inline = true;
        p1.set (Key.from_str ("name"), new String.from_str ("A"));
        products.add (p1);
        root.set (Key.from_str ("products"), products);
        assert (Toml.write_string (root) == "products = [ { name = \"A\" } ]\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_dotted_keys () {
    try {
        var root = new Toml.Table ();
        root.style.dotted_keys = true;
        var a = new Toml.Table ();
        a.set (Key.from_str ("b"), new Integer (1));
        root.set (Key.from_str ("a"), a);
        assert (Toml.write_string (root) == "a.b = 1\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_offset_datetime_canonical () {
    try {
        var root = new Toml.Table ();
        var tz = new TimeZone.utc ();
        var dt = new DateTime (tz, 1979, 5, 27, 7, 32, 0.0);
        root.set (Key.from_str ("t"), new OffsetDateTime (dt));
        assert (Toml.write_string (root) == "t = 1979-05-27T07:32:00Z\n");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_f011_no_string_injection_api () {
    // Public API has no string datetime ctor — building an injected value is a compile error.
    // Runtime guard: parse rejects junk that would have been stored before.
    bool threw = false;
    try {
        Toml.parse_offset_datetime ("1970-01-01T00:00:00Z\nx = 1");
    } catch (Toml.ParseError e) {
        threw = true;
    }
    assert (threw);
}

Toml.Array nest_inline_arrays (int depth) throws Error {
    var inner = new Toml.Array ();
    inner.style.inline = true;
    for (int i = 0; i < depth - 1; i++) {
        var outer = new Toml.Array ();
        outer.style.inline = true;
        outer.add (inner);
        inner = outer;
    }
    return inner;
}

Toml.Table nest_standard_tables (int depth) throws Error {
    // depth nested tables under root key path t0.t1.… ; returns root
    var leaf = new Toml.Table ();
    leaf.set (Key.from_str ("v"), new Integer (1));
    var cur = leaf;
    for (int i = 0; i < depth - 1; i++) {
        var parent = new Toml.Table ();
        parent.set (Key.from_str ("t"), cur);
        cur = parent;
    }
    var root = new Toml.Table ();
    root.set (Key.from_str ("t"), cur);
    return root;
}

void test_write_inline_array_nesting_at_limit_ok () {
    try {
        var root = new Toml.Table ();
        // root + (MAX-1) arrays = MAX enters
        root.set (Key.from_str ("a"), nest_inline_arrays (Toml.MAX_VALUE_NESTING - 1));
        string s = Toml.write_string (root);
        assert (s != null && s.has_prefix ("a = "));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_inline_array_nesting_over_limit_fails () {
    try {
        var root = new Toml.Table ();
        root.set (Key.from_str ("a"), nest_inline_arrays (Toml.MAX_VALUE_NESTING));
        Toml.write_string (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_standard_table_nesting_over_limit_fails () {
    try {
        // root + MAX nested tables => MAX+1 enters
        var root = nest_standard_tables (Toml.MAX_VALUE_NESTING);
        Toml.write_string (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_write_cyclic_dom_fails () {
    var t = new Toml.Table ();
    t.style.inline = true;
    var a = new Toml.Array ();
    a.style.inline = true;
    t.set_unchecked (Key (new Bytes ("a".data)), a);
    a.add_unchecked (t);
    var root = new Toml.Table ();
    root.set_unchecked (Key (new Bytes ("x".data)), t);
    try {
        Toml.write_string (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

void test_write_error_inline_table_with_aot () {
    try {
        var root = new Toml.Table ();
        var bad = new Toml.Table ();
        bad.style.inline = true;
        var aot = new Toml.Array ();
        aot.add (new Toml.Table ());
        bad.set (Key.from_str ("x"), aot);
        root.set (Key.from_str ("bad"), bad);
        Toml.write_string (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        // expected
    } catch (Error e) {
        assert_no_error (e);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/writer/simple", test_write_simple);
    Test.add_func ("/toml/writer/nested_standard_table", test_write_nested_standard_table);
    Test.add_func ("/toml/writer/inline_table", test_write_inline_table);
    Test.add_func ("/toml/writer/multiline_inline_table", test_write_multiline_inline_table);
    Test.add_func ("/toml/writer/array_multiline", test_write_array_multiline);
    Test.add_func ("/toml/writer/multiline_indent_override", test_write_multiline_indent_override);
    Test.add_func ("/toml/writer/aot_standard", test_write_aot_standard);
    Test.add_func ("/toml/writer/aot_inline", test_write_aot_inline);
    Test.add_func ("/toml/writer/dotted_keys", test_write_dotted_keys);
    Test.add_func ("/toml/writer/offset_datetime_canonical", test_write_offset_datetime_canonical);
    Test.add_func ("/toml/writer/f011_no_string_injection_api", test_f011_no_string_injection_api);
    Test.add_func ("/toml/writer/error_inline_table_with_aot", test_write_error_inline_table_with_aot);
    Test.add_func ("/toml/writer/inline_array_nesting_at_limit_ok",
        test_write_inline_array_nesting_at_limit_ok);
    Test.add_func ("/toml/writer/inline_array_nesting_over_limit_fails",
        test_write_inline_array_nesting_over_limit_fails);
    Test.add_func ("/toml/writer/standard_table_nesting_over_limit_fails",
        test_write_standard_table_nesting_over_limit_fails);
    Test.add_func ("/toml/writer/cyclic_dom_fails", test_write_cyclic_dom_fails);
    return Test.run ();
}
