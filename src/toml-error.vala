namespace Toml {
    public errordomain ParseError {
        FAILED
    }

    public errordomain WriteError {
        FAILED
    }

    internal string format_parse_error (int line, int column, string message) {
        return "%d:%d: %s".printf (line, column, message);
    }
}
