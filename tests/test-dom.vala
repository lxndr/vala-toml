void test_library_name () {
    assert (Toml.library_name () == "vala-toml");
}

void test_parse_error_message () {
    try {
        throw new Toml.ParseError.FAILED ("1:5: unexpected token");
    } catch (Toml.ParseError e) {
        assert (e.message.contains ("1:5:"));
        return;
    }
    assert_not_reached ();
}

void test_style_defaults () {
    var ts = new Toml.TableStyle ();
    assert (!ts.inline);
    assert (!ts.dotted_keys);
    assert (!ts.multiline);
    assert (ts.indent == -1);

    var as_ = new Toml.ArrayStyle ();
    assert (!as_.inline);
    assert (!as_.multiline);
    assert (as_.indent == -1);

    var opts = new Toml.WriteOptions ();
    assert (opts.indent == 2);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/library_name", test_library_name);
    Test.add_func ("/toml/parse_error_message", test_parse_error_message);
    Test.add_func ("/toml/style_defaults", test_style_defaults);
    return Test.run ();
}
