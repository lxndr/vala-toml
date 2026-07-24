namespace Toml {
    /**
     * Formatting hints for a table when writing TOML.
     */
    public struct TableStyle {
        /** Prefer inline `{ ... }` form when possible. */
        [CCode (cname = "is_inline")]
        public bool inline;
        /** Prefer dotted keys for nested single-leaf tables. */
        public bool dotted_keys;
        /** Prefer multi-line layout when inline. */
        public bool multiline;
        /** Indent width override; negative means use WriteOptions.indent. */
        public int indent;

        public TableStyle () {
            this.inline = false;
            this.dotted_keys = false;
            this.multiline = false;
            this.indent = -1;
        }
    }

    /**
     * Formatting hints for an array when writing TOML.
     */
    public struct ArrayStyle {
        /** Prefer inline `[ ... ]` form when possible. */
        [CCode (cname = "is_inline")]
        public bool inline;
        /** Prefer multi-line layout when inline. */
        public bool multiline;
        /** Indent width override; negative means use WriteOptions.indent. */
        public int indent;

        public ArrayStyle () {
            this.inline = false;
            this.multiline = false;
            this.indent = -1;
        }
    }

    /**
     * Global options for TOML emission.
     */
    public struct WriteOptions {
        /** Default indent width in spaces. */
        public int indent;

        public WriteOptions () {
            this.indent = 2;
        }
    }
}
