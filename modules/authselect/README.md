# `authselect` Module

The `authselect` module can be used to enable/disable PAM authentication presets.
authselect wiki: https://github.com/authselect/authselect/wiki
builtin profiles: https://github.com/authselect/authselect/tree/master/profiles

## Usage

```yaml
type: authselect
preset: local
features:
	- with-mkhomedir
	- with-fingerprint
```
