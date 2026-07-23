namespace Toml {
    // public for v1: tests link via generated .vapi, which omits `internal` types
    public enum TokenKind {
        EOF,
        NEWLINE,
        EQUALS,
        DOT,
        COMMA,
        LBRACE,
        RBRACE,
        LBRACKET,
        RBRACKET,
        DOUBLE_LBRACKET,
        DOUBLE_RBRACKET,
        KEY,
        STRING,
        INTEGER,
        FLOAT,
        BOOLEAN,
        DATETIME,
        DATETIME_LOCAL,
        DATE_LOCAL,
        TIME_LOCAL
    }

    public class Token : Object {
        public TokenKind kind { get; private set; }
        public string text { get; private set; }
        public int line { get; private set; }
        public int column { get; private set; }

        public Token (TokenKind kind, string text, int line, int column) {
            this.kind = kind;
            this.text = text;
            this.line = line;
            this.column = column;
        }
    }
}
