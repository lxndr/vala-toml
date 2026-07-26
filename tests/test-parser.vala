using Toml;

void test_parse_simple_pair () {
    try {
        var t = Toml.parse_string ("a = 1\nb = \"hi\"\n");
        assert (((Integer) t.get (Key.from_str ("a"))).value == 1);
        assert (((String) t.get (Key.from_str ("b"))).to_string () == "hi");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_bool_float () {
    try {
        var t = Toml.parse_string ("ok = true\nn = 1.0\n");
        assert (((Boolean) t.get (Key.from_str ("ok"))).value == true);
        assert (t.get (Key.from_str ("n")) is Float);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_standard_table () {
    try {
        var t = Toml.parse_string ("[foo]\nbar = 1\n");
        assert (((Integer) ((Table) t.get (Key.from_str ("foo"))).get (Key.from_str ("bar"))).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_dotted_key () {
    try {
        var t = Toml.parse_string ("a.b.c = 1\n");
        assert (((Integer) ((Table) ((Table) t.get (Key.from_str ("a"))).get (Key.from_str ("b"))).get (Key.from_str ("c"))).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_dotted_key_then_header_fails () {
    try {
        Toml.parse_string ("a.b.c = 1\n[a.b]\n");
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.length > 0);
    }
}

void test_parse_value_then_header_fails () {
    try {
        Toml.parse_string ("a.b = 1\n[a.b]\n");
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.length > 0);
    }
}

void test_parse_header_then_dotted_key () {
    try {
        var t = Toml.parse_string ("[a]\nb.c = 1\n");
        assert (((Integer) ((Table) ((Table) t.get (Key.from_str ("a"))).get (Key.from_str ("b"))).get (Key.from_str ("c"))).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_header_implicit_reopen () {
    try {
        var t = Toml.parse_string ("[a.b]\nc = 1\n[a]\nd = 2\n");
        assert (((Integer) ((Table) ((Table) t.get (Key.from_str ("a"))).get (Key.from_str ("b"))).get (Key.from_str ("c"))).value == 1);
        assert (((Integer) ((Table) t.get (Key.from_str ("a"))).get (Key.from_str ("d"))).value == 2);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_duplicate_key_fails () {
    try {
        Toml.parse_string ("x = 1\nx = 2\n");
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.length > 0);
    }
}

string invalid_utf8_source () {
    // Lone 0xFF is never valid UTF-8. Null-terminated for Vala string bridging.
    uint8[] bytes = { 0xFF, 0 };
    return (string) bytes;
}

void test_parse_invalid_utf8_fails () {
    try {
        Toml.parse_string (invalid_utf8_source ());
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("invalid UTF-8"));
    }
}

void test_parse_numeric_bare_key () {
    try {
        var t = Toml.parse_string ("123 = 1\n");
        assert (((Integer) t.get (Key.from_str ("123"))).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_date_shaped_bare_key () {
    try {
        var t = Toml.parse_string ("1979-05-27 = 1\n");
        assert (((Integer) t.get (Key.from_str ("1979-05-27"))).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_signed_integer_key_fails () {
    try {
        Toml.parse_string ("+1 = 1\n");
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.length > 0);
    }
}

void test_parse_array () {
    try {
        var t = Toml.parse_string ("nums = [1, 2, 3]\n");
        var a = (Toml.Array) t.get (Key.from_str ("nums"));
        assert (a.size == 3);
        assert (!a.style.multiline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_inline_table_neutral_style () {
    try {
        var t = Toml.parse_string ("point = { x = 1, y = 2 }\n");
        var p = (Table) t.get (Key.from_str ("point"));
        assert (((Integer) p.get (Key.from_str ("x"))).value == 1);
        assert (!p.style.inline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_array_of_tables () {
    try {
        var t = Toml.parse_string ("[[products]]\nname = \"A\"\n[[products]]\nname = \"B\"\n");
        var a = (Toml.Array) t.get (Key.from_str ("products"));
        assert (a.size == 2);
        assert (((String) ((Table) a.get (0)).get (Key.from_str ("name"))).to_string () == "A");
        assert (((String) ((Table) a.get (1)).get (Key.from_str ("name"))).to_string () == "B");
        assert (!a.style.inline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

string nest_arrays (int depth) {
    var open = string.nfill (depth, '[');
    var close = string.nfill (depth, ']');
    return "a = %s%s\n".printf (open, close);
}

string nest_inline_tables (int depth) {
    var sb = new StringBuilder ("a = ");
    for (int i = 0; i < depth; i++) {
        sb.append ("{ a = ");
    }
    sb.append ("1");
    for (int i = 0; i < depth; i++) {
        sb.append (" }");
    }
    sb.append ("\n");
    return sb.str;
}

string nest_dotted_assignment (int depth) {
    // depth container hops from root inclusive along tables; scalar leaf.
    // depth==1 → "a = 1\n" (only root + scalar; no nested table)
    // depth>=2 → (depth-1) dotted prefixes + final key
    if (depth < 2) {
        return "a = 1\n";
    }
    var sb = new StringBuilder ();
    for (int i = 0; i < depth - 1; i++) {
        if (i > 0) {
            sb.append (".");
        }
        sb.append ("a");
    }
    sb.append (".z = 1\n");
    return sb.str;
}

string nest_header_path (int depth) {
    // [a.a.…] with (depth-1) segments then z, plus z key — pin to same container depth as dotted
    if (depth < 2) {
        return "[a]\nx = 1\n";
    }
    var sb = new StringBuilder ("[");
    for (int i = 0; i < depth - 1; i++) {
        if (i > 0) {
            sb.append (".");
        }
        sb.append ("a");
    }
    sb.append ("]\nx = 1\n");
    return sb.str;
}

void test_parse_dotted_nesting_over_limit_fails () {
    try {
        Toml.parse_string (nest_dotted_assignment (Toml.MAX_VALUE_DEPTH + 1));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_header_nesting_over_limit_fails () {
    try {
        Toml.parse_string (nest_header_path (Toml.MAX_VALUE_DEPTH + 1));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_dotted_nesting_at_limit_ok () {
    try {
        var t = Toml.parse_string (nest_dotted_assignment (Toml.MAX_VALUE_DEPTH));
        assert (t != null);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_header_nesting_at_limit_ok () {
    try {
        var t = Toml.parse_string (nest_header_path (Toml.MAX_VALUE_DEPTH));
        assert (t != null);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_string_embedded_nul_roundtrip () {
    try {
        // basic string with \u0000
        var t = Toml.parse_string ("s = \"a\\u0000b\"\n");
        var s = (String) t.get (Key.from_str ("s"));
        unowned uint8[] d = s.bytes.get_data ();
        assert (d.length == 3);
        assert (d[0] == 'a' && d[1] == 0 && d[2] == 'b');
        assert (s.to_string () == "a");

        string written = Toml.write_string (t);
        var t2 = Toml.parse_string (written);
        var s2 = (String) t2.get (Key.from_str ("s"));
        assert (s2.bytes.compare (s.bytes) == 0);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_key_embedded_nul_roundtrip () {
    try {
        var t = Toml.parse_string ("\"a\\u0000b\" = 1\n");
        uint8[] raw = { 'a', 0, 'b' };
        var k = Key (new Bytes (raw));
        assert (t.has (k));
        assert (((Integer) t.get (k)).value == 1);

        string written = Toml.write_string (t);
        var t2 = Toml.parse_string (written);
        assert (((Integer) t2.get (k)).value == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_array_nesting_over_limit_fails () {
    try {
        // Root counts: MAX array hops under root reach depth MAX+1 and must fail.
        Toml.parse_string (nest_arrays (Toml.MAX_VALUE_DEPTH));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_inline_table_nesting_over_limit_fails () {
    try {
        Toml.parse_string (nest_inline_tables (Toml.MAX_VALUE_DEPTH));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/parser/simple_pair", test_parse_simple_pair);
    Test.add_func ("/toml/parser/bool_float", test_parse_bool_float);
    Test.add_func ("/toml/parser/standard_table", test_parse_standard_table);
    Test.add_func ("/toml/parser/dotted_key", test_parse_dotted_key);
    Test.add_func ("/toml/parser/dotted_key_then_header_fails", test_parse_dotted_key_then_header_fails);
    Test.add_func ("/toml/parser/value_then_header_fails", test_parse_value_then_header_fails);
    Test.add_func ("/toml/parser/header_then_dotted_key", test_parse_header_then_dotted_key);
    Test.add_func ("/toml/parser/header_implicit_reopen", test_parse_header_implicit_reopen);
    Test.add_func ("/toml/parser/duplicate_key_fails", test_parse_duplicate_key_fails);
    Test.add_func ("/toml/parser/invalid_utf8_fails", test_parse_invalid_utf8_fails);
    Test.add_func ("/toml/parser/numeric_bare_key", test_parse_numeric_bare_key);
    Test.add_func ("/toml/parser/date_shaped_bare_key", test_parse_date_shaped_bare_key);
    Test.add_func ("/toml/parser/signed_integer_key_fails", test_parse_signed_integer_key_fails);
    Test.add_func ("/toml/parser/array", test_parse_array);
    Test.add_func ("/toml/parser/inline_table_neutral_style", test_parse_inline_table_neutral_style);
    Test.add_func ("/toml/parser/array_of_tables", test_parse_array_of_tables);
    Test.add_func ("/toml/parser/array_nesting_over_limit_fails", test_parse_array_nesting_over_limit_fails);
    Test.add_func ("/toml/parser/inline_table_nesting_over_limit_fails", test_parse_inline_table_nesting_over_limit_fails);
    Test.add_func ("/toml/parser/dotted_nesting_over_limit_fails", test_parse_dotted_nesting_over_limit_fails);
    Test.add_func ("/toml/parser/header_nesting_over_limit_fails", test_parse_header_nesting_over_limit_fails);
    Test.add_func ("/toml/parser/dotted_nesting_at_limit_ok", test_parse_dotted_nesting_at_limit_ok);
    Test.add_func ("/toml/parser/header_nesting_at_limit_ok", test_parse_header_nesting_at_limit_ok);
    Test.add_func ("/toml/parser/string_embedded_nul_roundtrip", test_string_embedded_nul_roundtrip);
    Test.add_func ("/toml/parser/key_embedded_nul_roundtrip", test_key_embedded_nul_roundtrip);
    return Test.run ();
}
