namespace Toml {
    public class TableStyle : Object {
        public bool inline { get; set; default = false; }
        public bool dotted_keys { get; set; default = false; }
        public bool multiline { get; set; default = false; }
        public int indent { get; set; default = -1; }
    }

    public class ArrayStyle : Object {
        public bool inline { get; set; default = false; }
        public bool multiline { get; set; default = false; }
        public int indent { get; set; default = -1; }
    }

    public class WriteOptions : Object {
        public int indent { get; set; default = 2; }
    }
}
