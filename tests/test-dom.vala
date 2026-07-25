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
    try {
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
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_array_basic () {
    try {
        var a = new Toml.Array ();
        a.add (Toml.Value.from_boolean (true));
        a.add (Toml.Value.from_float (1.5));
        assert (a.size == 2);
        assert (a.get (0).get_boolean () == true);
        assert (a.get (1).get_float () == 1.5);
        assert (!a.style.multiline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_nested_table () {
    try {
        var root = new Toml.Table ();
        var child = new Toml.Table ();
        child.set ("x", Toml.Value.from_integer (9));
        root.set ("child", child);
        assert (root.get ("child").as_table ().get ("x").get_integer () == 9);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_table_set_self_cycle_fails () {
    var t = new Toml.Table ();
    try {
        t.set ("x", t);
        assert_not_reached ();
    } catch (Toml.ValueError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

void test_table_array_cycle_fails () {
    var t = new Toml.Table ();
    var a = new Toml.Array ();
    try {
        t.set ("a", a);
        a.add (t);
        assert_not_reached ();
    } catch (Toml.ValueError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

Toml.Table nest_standard_tables (int depth) throws Toml.ValueError {
    var leaf = new Toml.Table ();
    leaf.set ("v", Toml.Value.from_integer (1));
    var cur = leaf;
    for (int i = 0; i < depth - 1; i++) {
        var parent = new Toml.Table ();
        parent.set ("t", cur);
        cur = parent;
    }
    var root = new Toml.Table ();
    root.set ("t", cur);
    return root;
}

void test_deep_table_destroy_ok () {
    try {
        var root = nest_standard_tables (Toml.MAX_VALUE_NESTING);
        root = null;
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_shared_table_survives_sibling_destroy () {
    try {
        var shared = new Toml.Table ();
        shared.set ("keep", Toml.Value.from_integer (42));

        var dying = new Toml.Table ();
        dying.set ("shared", shared);

        var live = new Toml.Table ();
        live.set ("shared", shared);

        dying = null;

        assert (live.get ("shared").as_table ().get ("keep").get_integer () == 42);
        assert (shared.get ("keep").get_integer () == 42);
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

/*
 * Double-edge chain: each parent holds the same child under two keys.
 * The old ref_count==2 rule skips every child (rc>=3), then each layer
 * finalizes recursively when the parent clears — SIGSEGV on deep DAGs
 * (repro: ulimit -s 256).
 */
void test_diamond_join_deep_destroy_ok () {
    try {
        var leaf = new Toml.Table ();
        leaf.set ("v", Toml.Value.from_integer (1));
        var cur = leaf;
        for (int i = 0; i < Toml.MAX_VALUE_NESTING; i++) {
            var parent = new Toml.Table ();
            parent.set ("a", cur);
            parent.set ("b", cur);
            cur = parent;
        }
        cur = null;
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
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
    Test.add_func ("/toml/dom/table_set_self_cycle_fails", test_table_set_self_cycle_fails);
    Test.add_func ("/toml/dom/table_array_cycle_fails", test_table_array_cycle_fails);
    Test.add_func ("/toml/dom/deep_table_destroy_ok", test_deep_table_destroy_ok);
    Test.add_func ("/toml/dom/shared_table_survives_sibling_destroy", test_shared_table_survives_sibling_destroy);
    Test.add_func ("/toml/dom/diamond_join_deep_destroy_ok", test_diamond_join_deep_destroy_ok);
    return Test.run ();
}
