using Toml;

void test_values_equal_ignores_style () {
    try {
        var a = new Toml.Table ();
        a.set (Key.from_str ("k"), new Integer (1));
        var b = new Toml.Table ();
        b.set (Key.from_str ("k"), new Integer (1));
        b.style.inline = true;
        assert (Toml.values_equal (a, b));
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_values_equal_detects_difference () {
    var a = new String.from_str ("x");
    var b = new String.from_str ("y");
    assert (!Toml.values_equal (a, b));
}

void test_roundtrip_values () {
    string[] samples = {
        "a = 1\n",
        "s = \"hi\"\n",
        "[t]\nx = true\n",
        "arr = [1, 2]\n",
        "[[a]]\nk = 1\n[[a]]\nk = 2\n",
    };
    try {
        foreach (var src in samples) {
            var t1 = Toml.parse_string (src);
            var out_ = Toml.write_string (t1);
            var t2 = Toml.parse_string (out_);
            assert (Toml.values_equal (t1, t2));
        }
    } catch (Error e) {
        assert_no_error (e);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/values_equal_ignores_style", test_values_equal_ignores_style);
    Test.add_func ("/toml/values_equal_detects_difference", test_values_equal_detects_difference);
    Test.add_func ("/toml/roundtrip_values", test_roundtrip_values);
    return Test.run ();
}
