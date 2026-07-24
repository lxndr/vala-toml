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

    public struct Token {
        public TokenKind kind;
        public string text;
        public uint8[]? bytes;
        public int line;
        public int column;

        public Token (TokenKind kind, string text, int line, int column) {
            this.kind = kind;
            this.text = text;
            this.bytes = null;
            this.line = line;
            this.column = column;
        }

        public Token.with_bytes (TokenKind kind, uint8[] bytes, int line, int column) {
            this.kind = kind;
            this.bytes = Value.bytes_copy (bytes);
            this.text = bytes_to_visible_text (this.bytes);
            this.line = line;
            this.column = column;
        }

        private static string bytes_to_visible_text (uint8[] bytes) {
            for (int i = 0; i < bytes.length; i++) {
                if (bytes[i] == 0) {
                    return "";
                }
            }
            var sb = new StringBuilder ();
            if (bytes.length > 0) {
                sb.append_len ((string) bytes, bytes.length);
            }
            return sb.str;
        }
    }
}
