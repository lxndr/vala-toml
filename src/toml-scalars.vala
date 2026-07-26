namespace Toml {
    public class Integer : Value {
        public int64 value { get; private set; }
        public Integer (int64 value) { this.value = value; }
    }

    public class Float : Value {
        public double value { get; private set; }
        public Float (double value) { this.value = value; }
    }

    public class Boolean : Value {
        public bool value { get; private set; }
        public Boolean (bool value) { this.value = value; }
    }

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
