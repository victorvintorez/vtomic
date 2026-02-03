#!/usr/bin/env nu

def main [] {
	let header = [
		"# Auto-generated aliases for uutils-coreutils",
		($"# Generated at build time on (date now)"),
		""
	]

	let aliases = (ls /usr/bin/uu_* | each { |bin|
			let tool_name = ($bin.name | path basename | str replace "uu_" "")

			[
				($"export alias og-($tool_name) = ^($tool_name)"),
				($"export alias ($tool_name) = ($bin.name | path basename)")
			]
	} | flatten)

	$header | append $aliases | str join (char newline) | save -f /etc/nushell/autoload/uutils.nu
}
