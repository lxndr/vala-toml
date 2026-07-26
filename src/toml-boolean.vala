namespace Toml {
    public class Boolean : Value {
        public bool value { get; private set; }
        public Boolean (bool value) { this.value = value; }
    }
}
