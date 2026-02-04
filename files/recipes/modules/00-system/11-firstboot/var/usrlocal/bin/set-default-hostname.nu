#!/usr/bin/env nu

def main [] {
	print "firstboot: setting default hostname..."
	if not ("/usr/etc/vtomic.yaml" | path exists) {
		print "firstboot: failed to set default hostname!"
		print "firstboot: couldn't find the vtomic.yaml metadata file at `/usr/etc/vtomic.yaml`"
		print "firstboot: re-run with `sudo systemctl start set-default-hostname.service`"
        print "firstboot: or run `sudo `"
		exit 1
	}
	let hostname = try {
		open "/usr/etc/vtomic.yaml" | get "hostname"
	} catch {
		print "firstboot: failed to set default hostname!"
		print "firstboot: couldn't open the vtomic.yaml metadata file, or the file does not contain the hostname key"
		print "firstboot: re-run with `sudo systemctl start set-default-hostname.service`"
        print "firstboot: or run `sudo `"
		exit 1
	}
	try {
		hostnamectl hostname $hostname
	} catch {
		print "firstboot: failed to set default hostname!"
		print "firstboot: couldn't set the default hostname"
		print "firstboot: re-run with `sudo systemctl start set-default-hostname.service`"
        print "firstboot: or run `sudo `"
		exit 1
	}
	print "firstboot: set default hostname successfully!"
	systemctl disable --now set-default-hostname.service
	exit 0
}
