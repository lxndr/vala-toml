namespace Toml {
    public struct TableStyle {
        [CCode (cname = "is_inline")]
        public bool inline;
        public bool dotted_keys;
        public bool multiline;
        public int indent;

        public TableStyle () {
            this.inline = false;
            this.dotted_keys = false;
            this.multiline = false;
            this.indent = -1;
        }
    }

    public struct ArrayStyle {
        [CCode (cname = "is_inline")]
        public bool inline;
        public bool multiline;
        public int indent;

        public ArrayStyle () {
            this.inline = false;
            this.multiline = false;
            this.indent = -1;
        }
    }

    public struct WriteOptions {
        public int indent;

        public WriteOptions () {
            this.indent = 2;
        }
    }
}
