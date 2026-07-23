void test_write_simple () {
    try {
        var t = new Toml.Table ();
        t.set ("a", Toml.Value.from_integer (1));
        t.set ("b", Toml.Value.from_string ("x"));
        var s = Toml.write_string (t);
        assert (s.contains ("a = 1"));
        assert (s.contains ("b = \"x\""));
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_write_nested_standard_table () {
    try {
        var root = new Toml.Table ();
        var foo = new Toml.Table ();
        foo.set ("bar", Toml.Value.from_integer (1));
        root.set ("foo", foo);
        var s = Toml.write_string (root);
        assert (s.contains ("[foo]"));
        assert (s.contains ("bar = 1"));
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/writer/simple", test_write_simple);
    Test.add_func ("/toml/writer/nested_standard_table", test_write_nested_standard_table);
    return Test.run ();
}
