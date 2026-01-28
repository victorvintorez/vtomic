#!/usr/bin/env nu

def main [] {
	if (whoami) != "root" {
		print (gum style
			--foreground 196
			"this script requires root privileges!")
		print (gum style
			"please run as: sudo remove-setup-user.nu")

		exit 1
	}

	if (logname) == "setup" {
		print (gum style
			--foreground 196
			"this script cannot be run as the setup user!")
		print (gum style
			"hint: if you don't yet have a permenant user account, run `ujust setup-homed-user --firstboot`")

		exit 1
	}

	if (gum confirm
		--default=true
		"remove setup user?") == false {
			print (gum style
				--foreground 196
			"cancelled!")
			exit 0
		}

	try {
		sudo userdel -r setup
	} catch {
		print (gum style
			--foreground 196
			"oh no! setup user could not be removed, check system logs for details")
		exit 1
	}

	print (gum style
		--border double
		--margin "1"
		--padding "1 2"
		--border-foreground 46
		--
		"setup user removed successfully!")
}
