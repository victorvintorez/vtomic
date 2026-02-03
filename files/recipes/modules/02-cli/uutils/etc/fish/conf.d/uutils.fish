for binary in /usr/bin/uu_*
	if test -x "$binary"
		set -l tool_name (string replace -r '^.*/uu_' '' -- "$binary")

		alias "og-$tool_name"="command $tool_name"
		alias $tool_name="$binary"
	end
end
