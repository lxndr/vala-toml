void main () {
    var table = Toml.parse_string ("a = 1\n");
    var value = table.get ("a");
    assert (value != null);
    stdout.printf ("ok\n");
}
