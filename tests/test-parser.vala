void test_parse_simple_pair () {
    try {
        var t = Toml.parse_string ("a = 1\nb = \"hi\"\n");
        assert (t.get ("a").get_integer () == 1);
        assert (t.get ("b").get_string () == "hi");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_parse_bool_float () {
    try {
        var t = Toml.parse_string ("ok = true\nn = 1.0\n");
        assert (t.get ("ok").get_boolean () == true);
        assert (t.get ("n").kind == Toml.ValueKind.FLOAT);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_parse_dotted_key () {
    try {
        var t = Toml.parse_string ("a.b.c = 1\n");
        assert (t.get ("a").as_table ().get ("b").as_table ().get ("c").get_integer () == 1);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_parse_duplicate_key_fails () {
    try {
        Toml.parse_string ("x = 1\nx = 2\n");
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message != null && e.message.length > 0);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_parse_input_stream () {
    try {
        var bytes = new GLib.Bytes.take ("k = 42\n".data);
        var stream = new GLib.MemoryInputStream.from_bytes (bytes);
        var t = Toml.parse (stream);
        assert (t.get ("k").get_integer () == 42);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/parser/simple_pair", test_parse_simple_pair);
    Test.add_func ("/toml/parser/bool_float", test_parse_bool_float);
    Test.add_func ("/toml/parser/dotted_key", test_parse_dotted_key);
    Test.add_func ("/toml/parser/duplicate_key_fails", test_parse_duplicate_key_fails);
    Test.add_func ("/toml/parser/input_stream", test_parse_input_stream);
    return Test.run ();
}
