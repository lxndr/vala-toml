using Toml;

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
        t.set (Key.from_str ("b"), new String.from_str ("2"));
        t.set (Key.from_str ("a"), new Integer (1));
        assert (t.size == 2);
        assert (t.keys.get (0).equal_to (Key.from_str ("b")));
        assert (t.keys.get (1).equal_to (Key.from_str ("a")));
        assert (((Integer) t.get (Key.from_str ("a"))).value == 1);
        assert (((String) t.get (Key.from_str ("b"))).to_string () == "2");
        assert (t.style.inline == false);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_array_basic () {
    try {
        var a = new Toml.Array ();
        a.add (new Boolean (true));
        a.add (new Float (1.5));
        assert (a.size == 2);
        assert (((Boolean) a.get (0)).value == true);
        assert (((Float) a.get (1)).value == 1.5);
        assert (!a.style.multiline);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_nested_table () {
    try {
        var root = new Toml.Table ();
        var child = new Toml.Table ();
        child.set (Key.from_str ("x"), new Integer (9));
        root.set (Key.from_str ("child"), child);
        assert (((Integer) ((Table) root.get (Key.from_str ("child"))).get (Key.from_str ("x"))).value == 9);
    } catch (Error e) {
        assert_no_error (e);
    }
}

void test_table_set_self_cycle_fails () {
    var t = new Toml.Table ();
    try {
        t.set (Key.from_str ("x"), t);
        assert_not_reached ();
    } catch (Toml.ValueError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

void test_table_array_cycle_fails () {
    var t = new Toml.Table ();
    var a = new Toml.Array ();
    try {
        t.set (Key.from_str ("a"), a);
        a.add (t);
        assert_not_reached ();
    } catch (Toml.ValueError e) {
        assert (e.message != null && e.message.contains ("cyclic"));
    }
}

Toml.Table nest_standard_tables (int depth) throws Toml.ValueError {
    var leaf = new Toml.Table ();
    leaf.set (Key.from_str ("v"), new Integer (1));
    var cur = leaf;
    for (int i = 0; i < depth - 1; i++) {
        var parent = new Toml.Table ();
        parent.set (Key.from_str ("t"), cur);
        cur = parent;
    }
    var root = new Toml.Table ();
    root.set (Key.from_str ("t"), cur);
    return root;
}

void test_deep_table_destroy_ok () {
    try {
        var root = nest_standard_tables (Toml.MAX_VALUE_DEPTH);
        root = null;
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_shared_table_survives_sibling_destroy () {
    try {
        var shared = new Toml.Table ();
        shared.set (Key.from_str ("keep"), new Integer (42));

        var dying = new Toml.Table ();
        dying.set (Key.from_str ("shared"), shared);

        var live = new Toml.Table ();
        live.set (Key.from_str ("shared"), shared);

        dying = null;

        assert (((Integer) ((Table) live.get (Key.from_str ("shared"))).get (Key.from_str ("keep"))).value == 42);
        assert (((Integer) shared.get (Key.from_str ("keep"))).value == 42);
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

/*
 * A and B both hold shared S; S holds nested N (only reachable via S).
 * Edge-count alone marks N exclusive and clears it while S still lives.
 * Nested containers under externally shared seeds must be preserved.
 */
void test_shared_nested_survives_sibling_destroy () {
    try {
        var shared = new Toml.Table ();
        {
            var nested = new Toml.Table ();
            nested.set (Key.from_str ("keep"), new Integer (7));
            shared.set (Key.from_str ("nested"), nested);
        }

        var dying = new Toml.Table ();
        dying.set (Key.from_str ("shared"), shared);

        var live = new Toml.Table ();
        live.set (Key.from_str ("shared"), shared);

        dying = null;

        assert (((Integer) ((Table) ((Table) live.get (Key.from_str ("shared"))).get (Key.from_str ("nested"))).get (Key.from_str ("keep"))).value == 7);
        assert (((Integer) ((Table) shared.get (Key.from_str ("nested"))).get (Key.from_str ("keep"))).value == 7);
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
        leaf.set (Key.from_str ("v"), new Integer (1));
        var cur = leaf;
        for (int i = 0; i < Toml.MAX_VALUE_DEPTH; i++) {
            var parent = new Toml.Table ();
            parent.set (Key.from_str ("a"), cur);
            parent.set (Key.from_str ("b"), cur);
            cur = parent;
        }
        cur = null;
    } catch (Toml.ValueError e) {
        assert_not_reached ();
    }
}

void test_key_from_str_and_bytes () {
    var k1 = Toml.Key.from_str ("foo");
    assert (k1.to_string () == "foo");
    assert (k1.bytes.length == 3);

    uint8[] raw = { 'a', 0, 'b' };
    var k2 = Toml.Key (new Bytes (raw));
    assert (k2.bytes.length == 3);
    assert (k2.to_string () == "a"); // truncates at NUL
    unowned uint8[] d = k2.bytes.get_data ();
    assert (d[0] == 'a' && d[1] == 0 && d[2] == 'b');
}

void test_key_hash_equal_with_nul () {
    uint8[] raw = { 'a', 0, 'b' };
    var a = Toml.Key (new Bytes (raw));
    var b = Toml.Key (new Bytes (raw));
    var c = Toml.Key.from_str ("a");
    assert (a.equal_to (b));
    assert (a.hash () == b.hash ());
    assert (!a.equal_to (c));

    var map = new Gee.HashMap<Toml.Key?, int> (
        (k) => k.hash (),
        (a, b) => a.equal_to (b));
    map[a] = 1;
    assert (map[b] == 1);
    assert (!map.has_key (c));
}

void test_bytes_utf8_valid_allows_embedded_nul () {
    uint8[] raw = { 'a', 0, 'b' };
    assert (Toml.bytes_utf8_valid (new Bytes (raw)));
}

void test_bytes_utf8_valid_rejects_truncated_sequence () {
    uint8[] raw = { 0xE2, 0x82 }; // truncated UTF-8
    assert (!Toml.bytes_utf8_valid (new Bytes (raw)));
}

void test_bytes_utf8_valid_empty () {
    assert (Toml.bytes_utf8_valid (new Bytes ({})));
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
    Test.add_func ("/toml/dom/shared_nested_survives_sibling_destroy", test_shared_nested_survives_sibling_destroy);
    Test.add_func ("/toml/dom/diamond_join_deep_destroy_ok", test_diamond_join_deep_destroy_ok);
    Test.add_func ("/toml/dom/key_from_str_and_bytes", test_key_from_str_and_bytes);
    Test.add_func ("/toml/dom/key_hash_equal_with_nul", test_key_hash_equal_with_nul);
    Test.add_func ("/toml/dom/bytes_utf8_valid_allows_embedded_nul", test_bytes_utf8_valid_allows_embedded_nul);
    Test.add_func ("/toml/dom/bytes_utf8_valid_rejects_truncated_sequence", test_bytes_utf8_valid_rejects_truncated_sequence);
    Test.add_func ("/toml/dom/bytes_utf8_valid_empty", test_bytes_utf8_valid_empty);
    return Test.run ();
}
