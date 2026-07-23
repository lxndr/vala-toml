void test_library_name () {
    assert (Toml.library_name () == "vala-toml");
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/library_name", test_library_name);
    return Test.run ();
}
