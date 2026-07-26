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
    }

    public class LocalDate : Value {
        public Date value { get; private set; }
        public LocalDate (Date d) throws ValueError {
            if (!d.valid ()) {
                throw new ValueError.INVALID ("invalid date");
            }
            this.value = d;
        }
    }
}
