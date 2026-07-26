namespace Toml {
    public class LocalDateTime : Value {
        public Date date { get; private set; }
        public LocalTime time { get; private set; }

        public LocalDateTime (Date date, LocalTime time) throws ValueError {
            if (!date.valid ()) {
                throw new ValueError.INVALID ("invalid date");
            }

            this.date = date;
            this.time = time;
        }

        public bool equal_to (LocalDateTime other) {
            return this.date.get_year () == other.date.get_year ()
                && this.date.get_month () == other.date.get_month ()
                && this.date.get_day () == other.date.get_day ()
                && this.time.equal_to (other.time);
        }
    }
}
