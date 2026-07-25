void test_parse_simple_pair () {
    try {
        var t = Toml.parse_string ("a = 1\nb = \"hi\"\n");
        assert (t.get ("a").get_integer () == 1);
        assert (t.get ("b").get_string () == "hi");
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_bool_float () {
    try {
        var t = Toml.parse_string ("ok = true\nn = 1.0\n");
        assert (t.get ("ok").get_boolean () == true);
        assert (t.get ("n").kind == Toml.ValueKind.FLOAT);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_standard_table () {
    try {
        var t = Toml.parse_string ("[foo]\nbar = 1\n");
        assert (t.get ("foo").as_table ().get ("bar").get_integer () == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_dotted_key () {
    try {
        var t = Toml.parse_string ("a.b.c = 1\n");
        assert (t.get ("a").as_table ().get ("b").as_table ().get ("c").get_integer () == 1);
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
        assert (t.get ("a").as_table ().get ("b").as_table ().get ("c").get_integer () == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_header_implicit_reopen () {
    try {
        var t = Toml.parse_string ("[a.b]\nc = 1\n[a]\nd = 2\n");
        assert (t.get ("a").as_table ().get ("b").as_table ().get ("c").get_integer () == 1);
        assert (t.get ("a").as_table ().get ("d").get_integer () == 2);
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

void test_parse_input_stream () {
    try {
        var bytes = new GLib.Bytes.take ("k = 42\n".data);
        var stream = new GLib.MemoryInputStream.from_bytes (bytes);
        var t = Toml.parse (stream);
        assert (t.get ("k").get_integer () == 42);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_numeric_bare_key () {
    try {
        var t = Toml.parse_string ("123 = 1\n");
        assert (t.get ("123").get_integer () == 1);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_date_shaped_bare_key () {
    try {
        var t = Toml.parse_string ("1979-05-27 = 1\n");
        assert (t.get ("1979-05-27").get_integer () == 1);
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
        var a = t.get ("nums").as_array ();
        assert (a.size == 3);
        assert (!a.style.multiline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_inline_table_neutral_style () {
    try {
        var t = Toml.parse_string ("point = { x = 1, y = 2 }\n");
        var p = t.get ("point").as_table ();
        assert (p.get ("x").get_integer () == 1);
        assert (!p.style.inline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_array_of_tables () {
    try {
        var t = Toml.parse_string ("[[products]]\nname = \"A\"\n[[products]]\nname = \"B\"\n");
        var a = t.get ("products").as_array ();
        assert (a.size == 2);
        assert (a.get (0).as_table ().get ("name").get_string () == "A");
        assert (a.get (1).as_table ().get ("name").get_string () == "B");
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
        Toml.parse_string (nest_dotted_assignment (Toml.MAX_VALUE_NESTING + 1));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_header_nesting_over_limit_fails () {
    try {
        Toml.parse_string (nest_header_path (Toml.MAX_VALUE_NESTING + 1));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_dotted_nesting_at_limit_ok () {
    try {
        var t = Toml.parse_string (nest_dotted_assignment (Toml.MAX_VALUE_NESTING));
        assert (t != null);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_header_nesting_at_limit_ok () {
    try {
        var t = Toml.parse_string (nest_header_path (Toml.MAX_VALUE_NESTING));
        assert (t != null);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_parse_array_nesting_over_limit_fails () {
    try {
        // Root counts: MAX array hops under root reach depth MAX+1 and must fail.
        Toml.parse_string (nest_arrays (Toml.MAX_VALUE_NESTING));
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.contains ("nesting"));
    }
}

void test_parse_inline_table_nesting_over_limit_fails () {
    try {
        Toml.parse_string (nest_inline_tables (Toml.MAX_VALUE_NESTING));
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
    Test.add_func ("/toml/parser/input_stream", test_parse_input_stream);
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
    return Test.run ();
}
