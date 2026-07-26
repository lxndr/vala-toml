namespace Toml {
    public class Float : Value {
        public double value { get; private set; }
        public Float (double value) { this.value = value; }
    }
}
