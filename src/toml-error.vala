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

    /**
     * Error raised when constructing an invalid typed Value payload.
     */
    public errordomain ValueError {
        INVALID
    }

    internal string format_parse_error (int line, int column, string message) {
        return "%d:%d: %s".printf (line, column, message);
    }
}
