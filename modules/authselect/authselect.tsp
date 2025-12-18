import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema("/modules/authselect-latest.json")
model AuthSelectLatest {
	...AuthSelectV1;
}

@jsonSchema("/modules/authselect-v1.json")
model AuthSelectV1 {
	/** The `authselect` module can be used to enable/disable PAM authentication presets. */
	type: "authselect" | "authselect@v1" | "authselect@latest";

	/** Configuration of authselect preset */
	preset: "local" | "nis" | "sssd" | "winbind" | string;

	/** Configuration of authselect features to enable */
	features?: Array<string>;
}
