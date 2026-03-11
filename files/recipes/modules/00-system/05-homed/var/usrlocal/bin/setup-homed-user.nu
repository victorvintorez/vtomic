#!/usr/bin/env nu

def main [
	--dry-run
] {
	print (gum style
		--border normal
		--margin "1"
		--padding "1 2"
		--border-foreground 212
		"vtomic user setup")

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
			$"cancelled! you can restart by running `ujust setup-homed-user`")
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
			$"cancelled! you can restart by running `ujust setup-homed-user`")
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

	print (gum style
		--border normal
		--margin "1"
		--padding "1 2"
		--border-foreground 46
		"user created successfully!")
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
