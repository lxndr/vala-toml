#include <glib.h>
#include <glib-object.h>

/* Layout matches valac's struct _TomlValue for class Value. */
struct TomlValueRefCountLayout {
	GTypeInstance parent_instance;
	volatile int ref_count;
};

int
toml_value_peek_ref_count (void *instance)
{
	struct TomlValueRefCountLayout *self = instance;
	g_return_val_if_fail (self != NULL, 0);
	return g_atomic_int_get (&self->ref_count);
}
