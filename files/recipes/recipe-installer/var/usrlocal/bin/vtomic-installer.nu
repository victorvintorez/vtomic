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
		$"($GH_REPO) installer"
		"------"
		"you are currently using the installer image"
		"you will now be guided through:"
	    "1. setting up your user account"
	    $"2. choosing a ($GH_REPO) image")

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
		"phase 1: setting up your user account")
	print (gum style
		--foreground 99
		"step 1: identity")

	mut username = (gum input
		--placeholder "pick a username")

	loop {
		if ($username | is-empty) or ($username | str length) > 32 or ($username !~ '^[a-z_][a-z0-9_-]*$') or (logname) == $username or (homectl list | find $username | is-empty) == false {
			print (gum style
				--foreground 196
				"username must follow the following rules:")
			print (gum format
				--
				"- not be empty"
				"- less than 32 characters"
				"- begins with lowercase letter or underscore"
				"- contain only lowercase letters, numbers, underscore, or dashes"
				"- not be the currently logged in username"
				"- not already be managed by systemd-homed (tip: check with `homectl list`)")



			$username = (gum input
				--placeholder "pick a username")
		} else {
			break
		}
	}

	let realname = (gum input
		--placeholder "enter a fullname")

	let shell_choice = (gum choose
		--header "choose a shell"
		"fish" "nu")
	let shell = match $shell_choice {
		"nu" => (which nu | first),
		_ => (which fish | first)
	}

	print (char newline)
	print (gum style
		--foreground 99
		"step 2: storage")

	let current_disk = get_current_disk

	let available_disks = get_disks | where $it.id != $current_disk

	let disk_choice = (gum choose
		--header "choose which disk to use for user home"
		"current disk (recommended)" ...$available_disks.display)

	let selected_fs = match $disk_choice {
		"current disk (recommended)" => "current"
		_ => $"($available_disks | where $it.display == $disk_choice | first | get id)"
	}

	let valid_storage_types = if $selected_fs == "current" {
		match (findmnt -n -o FSTYPE --target /home) {
			"btrfs" => ["directory", "subvolume", "luks"],
			"ext4" => ["directory", "fscrypt", "luks"],
			"xfs" => ["directory", "luks"],
			"zfs" => ["directory"],
			"f2fs" => ["directory", "fscrypt", "luks"],
			"ubifs" => ["directory", "fscrypt", "luks"]
		}
	} else {
		["luks"]
	}

	let storage_type = (gum choose
		--header "choose a storage method"
		...$valid_storage_types)

	print (char newline)
	print (gum style
		--foreground 99
		"step 3: summary & confirmation")

	print (gum style
		--foreground 212
		--
		"summary:"
		"------"
		$"user: '($username)'"
		$"fullname: '($realname)'"
		$"shell: '($shell | get command)'"
		$"storage mode: '($storage_type)'"
		$"storage device: '($selected_fs)'")

	if (gum confirm
		--default=true
		"create user?") == false {
			print (gum style
				--foreground 196
			$"cancelled! you can restart by running `ujust setup-homed-user(if $firstboot {" --firstboot"})`")
			exit 0
		}

	if ($selected_fs != "current") and (gum confirm
		--prompt.foreground 196
		--affirmative "i am sure!"
		--negative "cancel!"
		--default=false
		$"this will wipe device ($disk_choice)! are you sure you want to continue?") == false {
			print (gum style
				--foreground 196
			$"cancelled! you can restart by running `ujust setup-homed-user(if $firstboot {" --firstboot"})`")
			exit 0
		}

	if ($storage_type == "fscrypt") or ($storage_type == "luks") {

		print (gum style
			"you will now be prompted for an encryption password")
	}

	if $dry_run == false {
		try {
			if ($selected_fs == "current") {
				(homectl create $username
					--real-name=$realname
					--shell=$($shell | get path)
					--storage=$storage_type
					--member-of=wheel)
			} else {
				(homectl create $username
					--real-name=$"($realname)"
					--shell=$($shell | get path)
					--storage=$storage_type
					--image-path=$selected_fs
					--member-of=wheel)
			}
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
		if ($selected_fs == "current") {
			print (gum format
				--
				"```"
			 	$"homectl create ($username) \\"
				$"	--real-name=($realname) \\"
				$"	--shell=($shell | get path) \\"
				$"	--storage=($storage_type) \\"
				"	--member-of=wheel"
				"```")
		} else {
			print (gum format
				--
				"```"
			 	$"homectl create ($username) \\"
				$"--real-name=($realname) \\"
				$"--shell=($shell | get path) \\"
				$"--storage=($storage_type) \\"
				$"--image-path=($selected_fs) \\"
				"--member-of=wheel"
				"```")
		}
	}

	print (char newline)
	print (gum style
		--foreground 99
		$"phase 2: choosing your ($GH_REPO)")
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

	update_signing_policy

	if $dry_run == false {
		try {
			(bootc switch
			    --enforce-container-sigpolicy
				$"ghcr.io/($GH_USER)/($selected_image)")
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
			"   --enforce-container-sigpolicy"
			$"	ghcr.io/($GH_USER)/($selected_image)"
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

def get_disks [] {
	let disk_details = (
		lsblk --json --bytes --output NAME,SIZE,MODEL,TYPE,SERIAL
		| from json
		| get blockdevices
		| where type == "disk"
		| select name size model serial
	)

	let disk_ids = (
		ls /dev/disk/by-id/
		| where type == symlink
		| where ($it.name | path basename) !~ '-part[0-9]+$'
		| where ($it.name | path basename) !~ 'wwn|eui'
		| select name
		| insert target { |row|
			$row.name
			| path expand
			| path basename
		}
	)

	let disks = $disk_ids
	| join $disk_details target name
	| uniq-by serial
	| select model name size
	| rename name path size
	| update size { |row| $row.size | into filesize }
	| sort-by path

	return ($disks | each { |disk|
		{
			id: $disk.path,
			display: $"($disk.name) \(($disk.size)\)"
		}
	})
}

def get_current_disk [] {
	let partition_name = (
		findmnt -n -o SOURCE -T /home
		| str replace -r '\[.*\]' ''
	)

	let disk_name = (
		lsblk --json --list -o PATH,TYPE -s $partition_name
		| from json
		| get blockdevices
		| where type == "disk"
		| first
		| get path
	)

	ls /dev/disk/by-id/
	| where type == symlink
	| where $it.name !~ '-part[0-9]+$'
	| where $it.name !~ "wwn|eui"
	| where ($it.name | path expand) == $disk_name
	| get name
	| sort
	| first
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

	let selected_wifi = ($available_wifi | where $it.ssid == $wifi_choice | first)

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
		exit 1
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

def update_signing_policy [] {
    if ("etc/pki/containers" | path type) == "dir" {
        mkdir "/etc/pki/containers"
    }

    try {
        (http get $"https://raw.githubusercontent.com/($GH_USER)/($GH_REPO)/($GH_BRANCH)/cosign.pub"
            | save -f $"/etc/pki/containers/($GH_REPO).pub")
    } catch {
    	print (gum style
			--foreground 196
			"oh no! couldn't connect to github! you can restart by running `vtomic-installer.nu`")
		exit 1
    }

    (open "/etc/containers/policy.json"
        | upsert transports { |transports_obj|
            let current_transports = ($transports_obj.transports? | default {})

            $current_transports | upsert docker { |docker_obj|
                let current_docker = ($docker_obj.docker? | default {})

                $current_docker | upsert $"ghcr.io/($GH_USER)" [{
                    type: "sigstoreSigned",
                    keyPath: $"/etc/pki/containers/($GH_REPO).pub",
                    signedIdentity: {
                        type: "matchRepository"
                    }
                }]
            }
        }
        | save -f "/etc/containers/policy.json")
}
