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

void test_lexer_rejects_quoted_string () {
    var lex = new Toml.Lexer ("\"hi\"");
    try {
        lex.next ();
        assert_not_reached ();
    } catch (Toml.ParseError e) {
        assert (e.message.contains (":"));
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

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/toml/lexer/key_equals_number", test_lexer_key_equals_number);
    Test.add_func ("/toml/lexer/skips_comment", test_lexer_skips_comment);
    Test.add_func ("/toml/lexer/brackets", test_lexer_brackets);
    Test.add_func ("/toml/lexer/punctuation_and_float", test_lexer_punctuation_and_float);
    Test.add_func ("/toml/lexer/hex_and_bool_false", test_lexer_hex_and_bool_false);
    Test.add_func ("/toml/lexer/rejects_quoted_string", test_lexer_rejects_quoted_string);
    Test.add_func ("/toml/lexer/line_column", test_lexer_line_column);
    return Test.run ();
}
