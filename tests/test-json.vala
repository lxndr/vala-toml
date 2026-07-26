using Toml;

void test_json_roundtrip_scalar () {
    try {
        var t = Toml.parse_string ("a = 1\n");
        var json = Toml.table_to_tagged_json (t);
        assert (json.contains ("\"type\": \"integer\"") || json.contains ("\"type\":\"integer\""));
        var t2 = Toml.table_from_tagged_json (json);
        assert (Toml.values_equal (t, t2));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_json_roundtrip_types () {
    string[] samples = {
        "s = \"hi\"\n",
        "i = 42\n",
        "f = 1.5\n",
        "b = true\n",
        "d = 1979-05-27T07:32:00Z\n",
        "dl = 1979-05-27T07:32:00\n",
        "date = 1979-05-27\n",
        "time = 07:32:00\n",
        "arr = [1, 2]\n",
        "[t]\nx = 1\n",
    };
    try {
        foreach (var src in samples) {
            var t1 = Toml.parse_string (src);
            var json = Toml.table_to_tagged_json (t1);
            var t2 = Toml.table_from_tagged_json (json);
            assert (Toml.values_equal (t1, t2));
        }
    } catch (Error e) {
        assert_no_error (e);
    }
}

string nest_json_objects (int depth) {
    string inner = "{\"type\":\"integer\",\"value\":\"1\"}";
    for (int i = 0; i < depth - 1; i++) {
        inner = "{\"k\":" + inner + "}";
    }
    return inner;
}

Toml.Array nest_inline_arrays (int depth) throws Error {
    var inner = new Toml.Array ();
    inner.style.inline = true;
    if (depth < 1) {
        return inner;
    }
    for (int i = 0; i < depth - 1; i++) {
        var outer = new Toml.Array ();
        outer.style.inline = true;
        outer.add (inner);
        inner = outer;
    }
    return inner;
}

void test_json_decode_nesting_over_limit_fails () {
    try {
        Toml.table_from_tagged_json (nest_json_objects (Toml.MAX_VALUE_DEPTH + 1));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    } catch (Error e) {
        assert_not_reached ();
    }
}

void test_json_encode_nesting_over_limit_fails () {
    try {
        var root = new Toml.Table ();
        root.set (Key.from_str ("a"), nest_inline_arrays (Toml.MAX_VALUE_DEPTH));
        Toml.table_to_tagged_json (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_json_decode_nesting_at_limit_ok () {
    try {
        var t = Toml.table_from_tagged_json (nest_json_objects (Toml.MAX_VALUE_DEPTH));
        assert (t != null);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_json_encode_nesting_at_limit_ok () {
    try {
        var root = new Toml.Table ();
        // root + (MAX-1) arrays = MAX enters
        root.set (Key.from_str ("a"), nest_inline_arrays (Toml.MAX_VALUE_DEPTH - 1));
        string json = Toml.table_to_tagged_json (root);
        assert (json != null && json.has_prefix ("{"));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_json_encode_cyclic_dom_fails () {
    var t = new Toml.Table ();
    t.style.inline = true;
    var a = new Toml.Array ();
    a.style.inline = true;
    t.set_unchecked (Key (new Bytes ("a".data)), a);
    a.add_unchecked (t);
    var root = new Toml.Table ();
    root.set_unchecked (Key (new Bytes ("x".data)), t);
    try {
        Toml.table_to_tagged_json (root);
        assert_not_reached ();
    } catch (Toml.WriteError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/json_roundtrip_scalar", test_json_roundtrip_scalar);
    Test.add_func ("/toml/json_roundtrip_types", test_json_roundtrip_types);
    Test.add_func ("/toml/json/decode_nesting_over_limit_fails",
        test_json_decode_nesting_over_limit_fails);
    Test.add_func ("/toml/json/encode_nesting_over_limit_fails",
        test_json_encode_nesting_over_limit_fails);
    Test.add_func ("/toml/json/encode_cyclic_dom_fails",
        test_json_encode_cyclic_dom_fails);
    Test.add_func ("/toml/json/decode_nesting_at_limit_ok",
        test_json_decode_nesting_at_limit_ok);
    Test.add_func ("/toml/json/encode_nesting_at_limit_ok",
        test_json_encode_nesting_at_limit_ok);
    return Test.run ();
}
