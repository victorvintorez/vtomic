#!/usr/bin/env nu

const GH_USER = "victorvintorez"
const GH_REPO = "vtomic"
const GH_BRANCH = "system"
const GH_RECIPE_PATH = "recipes"

def main [
	--dry-run
] {
	print (gum style
		--border normal
		--margin "1"
		--padding "1 2"
		--border-foreground 212
		--
		"vtomic installer"
		"------"
		"you are currently using the installer image"
		"you will now be guided through picking a specific vtomic image")

	if (whoami) != "root" {
		print (gum style
			--foreground 196
			"this script requires root privileges!")
		print (gum style
			"please run as: sudo setup-homed-user.nu")

		exit 1
	}

	print (char newline)
	print (gum style
		--foreground 99
		"step 1: internet")

	loop {
		let status = (do -i { nmcli networking connectivity check } | complete)

		if ($status.stdout | str trim) == "full" {
			print (gum style
				--foreground 46
				"internet connected!")
			break
		}

		print (gum style
			--foreground 196
			"no internet connection!")
		print (gum style
			"you must be connected to the internet to install vtomic images!")

		let connection_type = (gum choose
			--header "choose a connection method"
			"wifi"
			"wired"
			"manual setup")

		match $connection_type {
			"wifi" => setup_wifi,
			_ => wait_for_connection
		}
	}

	print (char newline)
	print (gum style
		--foreground 99
		"step 2: select an image")

	let available_images = fetch_images

	let image_choice = (gum choose
		--header "choose which image to install"
		...$available_images.display)

	let selected_image = $"($available_images | where $it.display == $image_choice | first | get id)"

	print (char newline)
	print (gum style
		--foreground 99
		"step 3: summary & confirmation")

	print (gum style
		--foreground 212
		$"selected image: ($selected_image)")

	if (gum confirm
		--default=true
		"install image?") == false {
			print (gum style
				--foreground 196
			$"cancelled! you can restart by running `vtomic-installer.nu`")
			exit 0
		}

	if $dry_run == false {
		try {
			(bootc switch
				$"ostree-image-signed:docker://ghcr.io/($GH_USER)/($selected_image)")
		} catch {
			print (gum style
				--foreground 196
				"oh no! user could not be created, check system logs for details")
			exit 1
		}
	} else {
		print (gum style
			--foreground 46
			"dry-run mode: this is the command that would be run!")
		print (gum format
			--
			"```"
			"bootc switch \\"
			$"	ostree-image-signed:docker://ghcr.io/($GH_USER)/($selected_image)"
			"```")
	}

	print (gum style
		--border normal
		--margin "1"
		--padding "1 2"
		--border-foreground 46
		--
		"image installed successfully!"
		"------"
		"1. reboot into the new image"
		"2. follow the instructions to set up your user account")
}

def setup_wifi [] {
	let available_wifi = (nmcli -t -f SSID,SECURITY device wifi list --rescan yes
		| lines
		| split column ":" ssid sec
		| where ssid != ""
		| uniq-by ssid)

	if ($available_wifi | is-empty) {
		print (gum style
			--foreground 196
			"oh no! no valid wifi networks could be found!")
		return
	}

	let wifi_choice = (gum choose
		--header "choose which wifi network to attempt connection"
		...$available_wifi.ssid)

	let selected_wifi = ($available_wifi | where $it.display == $wifi_choice | first)

	if ($selected_wifi | get sec) != "" or ($selected_wifi | get sec) != "--" {
		let password = (gum input
			--password
			--placeholder $"password for ($selected_wifi | get ssid)")

		if ($password | is-empty) {
			print (gum style
				--foreground 196
				"oh no! this wifi network requires a password!")
			return
		}

		(gum spin
			--spinner dot
			--title "waiting for internet..."
			--
			nmcli device wifi connect $"($selected_wifi | get ssid)" password $"($password)")
	} else {
		(gum spin
			--spinner dot
			--title "waiting for internet..."
			--
			nmcli device wifi connect $"($selected_wifi | get ssid)")
	}
}

def wait_for_connection [] {
	loop {
		let check = (do {
			(gum spin
				--spinner dot
				--title "waiting for internet..."
				--
				nm-online -q -t 60)
		} | complete)

		if $check.exit_code == 0 {
			print (gum style
				--foreground 46
				"found internet!")
			break
		}

		print (gum style
			--foreground 196
			"oh no! internet wasn't found before timeout... trying again!")
	}
}

def fetch_images [] {
	let api_url = $"https://api.github.com/repos/($GH_USER)/($GH_REPO)/contents/($GH_RECIPE_PATH)?ref=($GH_BRANCH)"

	let result = (try {
		(gum spin
			--spinner dot
			--title "fetching vtomic image list"
			--
			curl -fsSL $api_url)
	} catch {
		print (gum style
			--foreground 196
			"oh no! couldn't connect to github! you can restart by running `vtomic-installer.nu`")
		exit 0
	})

	let images = ($result
		| from json
		| where type == "file"
		| where name =~ '^recipe-.*\.yaml$'
		| par-each { |file|
			let yaml = http get $file.download_url

			{
				id: $"($yaml.name):br-system-($yaml.image-version)"
				display: $"($yaml.name) - ($yaml.description? | default "")"
			}
		})

	return $images
}
