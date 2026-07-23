void test_lexer_key_equals_number () {
    try {
        var lex = new Toml.Lexer ("answer = 42\n");
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        var n = lex.next ();
        assert (n.kind == Toml.TokenKind.INTEGER);
        assert (n.text == "42");
        assert (lex.next ().kind == Toml.TokenKind.NEWLINE);
        assert (lex.next ().kind == Toml.TokenKind.EOF);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_skips_comment () {
    try {
        var lex = new Toml.Lexer ("# hi\ntrue");
        assert (lex.next ().kind == Toml.TokenKind.NEWLINE);
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.BOOLEAN);
        assert (t.text == "true");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_brackets () {
    try {
        var lex = new Toml.Lexer ("[[]]");
        lex.key_mode = true;
        assert (lex.next ().kind == Toml.TokenKind.DOUBLE_LBRACKET);
        assert (lex.next ().kind == Toml.TokenKind.DOUBLE_RBRACKET);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_punctuation_and_float () {
    try {
        var lex = new Toml.Lexer ("a.b = { x = 1.5, y = -inf }\n");
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.DOT);
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        assert (lex.next ().kind == Toml.TokenKind.LBRACE);
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        var f = lex.next ();
        assert (f.kind == Toml.TokenKind.FLOAT);
        assert (f.text == "1.5");
        assert (lex.next ().kind == Toml.TokenKind.COMMA);
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        var inf = lex.next ();
        assert (inf.kind == Toml.TokenKind.FLOAT);
        assert (inf.text == "-inf");
        assert (lex.next ().kind == Toml.TokenKind.RBRACE);
        assert (lex.next ().kind == Toml.TokenKind.NEWLINE);
        assert (lex.next ().kind == Toml.TokenKind.EOF);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_hex_and_bool_false () {
    try {
        var lex = new Toml.Lexer ("flags = 0xDEAD_BEEF\nok = false");
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        var hex = lex.next ();
        assert (hex.kind == Toml.TokenKind.INTEGER);
        assert (hex.text == "0xDEAD_BEEF");
        assert (lex.next ().kind == Toml.TokenKind.NEWLINE);
        assert (lex.next ().kind == Toml.TokenKind.KEY);
        assert (lex.next ().kind == Toml.TokenKind.EQUALS);
        var b = lex.next ();
        assert (b.kind == Toml.TokenKind.BOOLEAN);
        assert (b.text == "false");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_line_column () {
    try {
        var lex = new Toml.Lexer ("  a = 1");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.KEY);
        assert (t.text == "a");
        assert (t.line == 1);
        assert (t.column == 3);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_basic_string_escape () {
    try {
        var lex = new Toml.Lexer ("\"a\\nb\"");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "a\nb");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_literal_string () {
    try {
        var lex = new Toml.Lexer ("'C:\\Users'");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "C:\\Users");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_multiline_basic () {
    try {
        var lex = new Toml.Lexer ("\"\"\"\nhello\nworld\"\"\"");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "hello\nworld");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_unicode_escapes () {
    try {
        var lex = new Toml.Lexer ("\"\\xE9\\u00E9\\U0001F600\"");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "éé😀");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_multiline_line_ending_backslash () {
    try {
        var lex = new Toml.Lexer ("\"\"\"\nThe quick brown \\\n\n  fox\"\"\"");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "The quick brown fox");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_multiline_literal () {
    try {
        var lex = new Toml.Lexer ("'''\nI [dw]on't need \\d{2} apples'''");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "I [dw]on't need \\d{2} apples");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_multiline_quotes_inside () {
    try {
        var lex = new Toml.Lexer ("\"\"\"Here are two quotation marks: \"\". Simple enough.\"\"\"");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.STRING);
        assert (t.text == "Here are two quotation marks: \"\". Simple enough.");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_rejects_bad_escape () {
    var lex = new Toml.Lexer ("\"\\q\"");
    try {
        lex.next ();
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message.contains (":"));
    }
}

void test_lexer_rejects_unterminated_string () {
    var lex = new Toml.Lexer ("\"hi");
    try {
        lex.next ();
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message.contains (":"));
    }
}

void test_lexer_offset_datetime () {
    try {
        var lex = new Toml.Lexer ("1979-05-27T07:32:00Z");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.DATETIME);
        assert (t.text == "1979-05-27T07:32:00Z");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_local_datetime () {
    try {
        var lex = new Toml.Lexer ("1979-05-27T07:32:00");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.DATETIME_LOCAL);
        assert (t.text == "1979-05-27T07:32:00");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_rejects_incomplete_offset () {
    var lex = new Toml.Lexer ("1979-05-27T07:32:00+01");
    try {
        lex.next ();
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message.contains (":"));
    }
}

void test_lexer_local_date () {
    try {
        var lex = new Toml.Lexer ("1979-05-27");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.DATE_LOCAL);
        assert (t.text == "1979-05-27");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_local_time () {
    try {
        var lex = new Toml.Lexer ("07:32:00");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.TIME_LOCAL);
        assert (t.text == "07:32:00");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

void test_lexer_integer_not_date () {
    try {
        var lex = new Toml.Lexer ("1979");
        var t = lex.next ();
        assert (t.kind == Toml.TokenKind.INTEGER);
        assert (t.text == "1979");
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/lexer/key_equals_number", test_lexer_key_equals_number);
    Test.add_func ("/toml/lexer/skips_comment", test_lexer_skips_comment);
    Test.add_func ("/toml/lexer/brackets", test_lexer_brackets);
    Test.add_func ("/toml/lexer/punctuation_and_float", test_lexer_punctuation_and_float);
    Test.add_func ("/toml/lexer/hex_and_bool_false", test_lexer_hex_and_bool_false);
    Test.add_func ("/toml/lexer/line_column", test_lexer_line_column);
    Test.add_func ("/toml/lexer/basic_string_escape", test_lexer_basic_string_escape);
    Test.add_func ("/toml/lexer/literal_string", test_lexer_literal_string);
    Test.add_func ("/toml/lexer/multiline_basic", test_lexer_multiline_basic);
    Test.add_func ("/toml/lexer/unicode_escapes", test_lexer_unicode_escapes);
    Test.add_func ("/toml/lexer/multiline_line_ending_backslash", test_lexer_multiline_line_ending_backslash);
    Test.add_func ("/toml/lexer/multiline_literal", test_lexer_multiline_literal);
    Test.add_func ("/toml/lexer/multiline_quotes_inside", test_lexer_multiline_quotes_inside);
    Test.add_func ("/toml/lexer/rejects_bad_escape", test_lexer_rejects_bad_escape);
    Test.add_func ("/toml/lexer/rejects_unterminated_string", test_lexer_rejects_unterminated_string);
    Test.add_func ("/toml/lexer/offset_datetime", test_lexer_offset_datetime);
    Test.add_func ("/toml/lexer/local_datetime", test_lexer_local_datetime);
    Test.add_func ("/toml/lexer/rejects_incomplete_offset", test_lexer_rejects_incomplete_offset);
    Test.add_func ("/toml/lexer/local_date", test_lexer_local_date);
    Test.add_func ("/toml/lexer/local_time", test_lexer_local_time);
    Test.add_func ("/toml/lexer/integer_not_date", test_lexer_integer_not_date);
    return Test.run ();
}
