namespace Toml {
    public class Integer : Value {
        public int64 value { get; private set; }
        public Integer (int64 value) { this.value = value; }
    }
}
