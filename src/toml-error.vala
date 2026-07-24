namespace Toml {
    /**
     * Error raised while parsing TOML.
     */
    public errordomain ParseError {
        FAILED
    }

    /**
     * Error raised while writing TOML.
     */
    public errordomain WriteError {
        FAILED
    }

    internal string format_parse_error (int line, int column, string message) {
        return "%d:%d: %s".printf (line, column, message);
    }
}
