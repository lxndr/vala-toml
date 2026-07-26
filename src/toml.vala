namespace Toml {
    /**
     * Parse TOML text into a DOM table.
     *
     * Validates that {@link text} is UTF-8. Control characters and bare
     * carriage returns are rejected later by the lexer per TOML 1.1.
     *
     * @param text UTF-8 TOML source
     * @return root table
     * @throws ParseError if the source is invalid UTF-8 or invalid TOML
     */
    public Table parse_string (string text) throws ParseError {
        if (text.length > 0 && !text.validate ()) {
            throw new ParseError.FAILED ("invalid UTF-8");
        }
        var parser = new Parser (text);
        return parser.parse ();
    }

    /**
     * Serialize a table to a TOML string.
     *
     * @param root table to emit
     * @param options writer options, or null for defaults
     * @return TOML text
     * @throws WriteError if the DOM cannot be emitted
     */
    public string write_string (Table root, WriteOptions? options = null) throws WriteError {
        var writer = new Writer (options);
        return writer.emit (root);
    }
}
