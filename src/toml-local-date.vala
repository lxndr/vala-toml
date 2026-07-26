namespace Toml {
    public class LocalDate : Value {
        public Date value { get; private set; }
        public LocalDate (Date d) throws ValueError {
            if (!d.valid ()) {
                throw new ValueError.INVALID ("invalid date");
            }
            this.value = d;
        }

        public bool equal_to (LocalDate other) {
            return this.value.compare (other.value) == 0;
        }
    }
}
