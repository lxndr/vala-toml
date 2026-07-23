void test_json_roundtrip_scalar () {
    try {
        var t = Toml.parse_string ("a = 1\n");
        var json = Toml.table_to_tagged_json (t);
        assert (json.contains ("\"type\": \"integer\"") || json.contains ("\"type\":\"integer\""));
        var t2 = Toml.table_from_tagged_json (json);
        assert (Toml.values_equal (t, t2));
    } catch (Error e) {
        error ("%s", e.message);
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
        error ("%s", e.message);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/json_roundtrip_scalar", test_json_roundtrip_scalar);
    Test.add_func ("/toml/json_roundtrip_types", test_json_roundtrip_types);
    return Test.run ();
}
