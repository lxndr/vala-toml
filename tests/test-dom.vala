void test_parse_error_message () {
    try {
        throw new Toml.ParseError.FAILED ("1:5: unexpected token");
    } catch (Toml.ParseError e) {
        assert (e.message.contains ("1:5:"));
    }
}

void test_style_defaults () {
    var ts = Toml.TableStyle ();
    assert (!ts.inline);
    assert (!ts.dotted_keys);
    assert (!ts.multiline);
    assert (ts.indent == -1);

    var as_ = Toml.ArrayStyle ();
    assert (!as_.inline);
    assert (!as_.multiline);
    assert (as_.indent == -1);

    var opts = Toml.WriteOptions ();
    assert (opts.indent == 2);
}

void test_table_insertion_order_and_get () {
    var t = new Toml.Table ();
    t.set ("b", Toml.Value.from_string ("2"));
    t.set ("a", Toml.Value.from_integer (1));
    assert (t.size == 2);
    assert (t.keys.get (0) == "b");
    assert (t.keys.get (1) == "a");
    assert (t.get ("a").get_integer () == 1);
    assert (t.get ("b").get_string () == "2");
    assert (t.as_table () == t);
    assert (t.style.inline == false);
}

void test_array_basic () {
    var a = new Toml.Array ();
    a.add (Toml.Value.from_boolean (true));
    a.add (Toml.Value.from_float (1.5));
    assert (a.size == 2);
    assert (a.get (0).get_boolean () == true);
    assert (a.get (1).get_float () == 1.5);
    assert (!a.style.multiline);
}

void test_nested_table () {
    var root = new Toml.Table ();
    var child = new Toml.Table ();
    child.set ("x", Toml.Value.from_integer (9));
    root.set ("child", child);
    assert (root.get ("child").as_table ().get ("x").get_integer () == 9);
}

void test_style_inplace_mutation () {
    var t = new Toml.Table ();
    t.style.inline = true;
    t.style.dotted_keys = true;
    t.style.multiline = true;
    t.style.indent = 4;
    assert (t.style.inline);
    assert (t.style.dotted_keys);
    assert (t.style.multiline);
    assert (t.style.indent == 4);

    var a = new Toml.Array ();
    a.style.inline = true;
    a.style.multiline = true;
    a.style.indent = 3;
    assert (a.style.inline);
    assert (a.style.multiline);
    assert (a.style.indent == 3);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/parse_error_message", test_parse_error_message);
    Test.add_func ("/toml/style_defaults", test_style_defaults);
    Test.add_func ("/toml/table_insertion_order_and_get", test_table_insertion_order_and_get);
    Test.add_func ("/toml/array_basic", test_array_basic);
    Test.add_func ("/toml/nested_table", test_nested_table);
    Test.add_func ("/toml/style_inplace_mutation", test_style_inplace_mutation);
    return Test.run ();
}
