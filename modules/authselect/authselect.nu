#!/usr/bin/env nu

def main [config: string]: nothing -> nothing {
	let config = $config
		| from json
		| default {}

	let preset = $config | get preset
	let features = $config | get features

	if ($preset != null || $preset | is-empty) {
		print $"(ansi red_bold)CONFIGURATION ERROR(ansi reset)"
		print $"(ansi yellow_reverse)HINT(ansi reset): (ansi default_italic)preset(ansi reset) cannot be empty!"
		exit 1
	}

	let preset_list = authselect list

	if (not(preset_list | str contains $preset)) {
		print $"(ansi red_bold)CONFIGURATION ERROR(ansi reset)"
		print $"(ansi yellow_reverse)HINT(ansi reset): (ansi default_italic)(preset)(ansi reset) is not in the list of available presets!"
		print $"Available Presets: (preset_list)"
		exit 1
	}

	let features_list = authselect list-features $preset

	for feature in $features {
		if (not(features_list | str contains $feature)) {
			print $"(ansi red_bold)CONFIGURATION ERROR(ansi reset)"
			print $"(ansi yellow_reverse)HINT(ansi reset): (ansi default_italic)(feature)(ansi reset) is not in the list of available features!"
			print $"Available Features: (features_list)"
			exit 1
		}
	}

	if (authselect current | str contains $preset) {
		for feature in $features {
			if (not(authselect is-feature-enabled $feature)) {
				authselect enable-feature $feature
			}
		}
	} else {
		authselect select $profile ($features | reduce { |feat str|  $str + $"(feat) " })
	}
	exit 0
}
