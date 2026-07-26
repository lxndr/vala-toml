namespace Toml {
    public class OffsetDateTime : Value {
        public DateTime value { get; private set; }
        public OffsetDateTime (DateTime dt) throws ValueError {
            if (dt == null) {
                throw new ValueError.INVALID ("offset date-time is null");
            }
            if (dt.get_timezone () == null) {
                throw new ValueError.INVALID ("offset date-time requires a timezone");
            }
            this.value = dt;
        }

        public bool equal_to (OffsetDateTime other) {
            DateTime a = this.value;
            DateTime b = other.value;
            return a.get_year () == b.get_year ()
                && a.get_month () == b.get_month ()
                && a.get_day_of_month () == b.get_day_of_month ()
                && a.get_hour () == b.get_hour ()
                && a.get_minute () == b.get_minute ()
                && a.get_second () == b.get_second ()
                && a.get_microsecond () == b.get_microsecond ()
                && a.get_utc_offset () == b.get_utc_offset ();
        }
    }
}
