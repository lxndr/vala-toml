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

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/library_name", test_library_name);
    Test.add_func ("/toml/parse_error_message", test_parse_error_message);
    return Test.run ();
}
