#!/usr/bin/env nu

def main [] {
	print "firstboot: resetting container policy.json file..."
	if not ("/usr/etc/containers/policy.json" | path exists) {
		print "firstboot: failed to reset container policy.json file!"
		print "firstboot: couldn't find default policy.json file at `/usr/etc/containers/policy.json`"
		print "firstboot: re-run with `sudo systemctl start reset-container-policy.service`"
        print "firstboot: or run `sudo cp /usr/etc/containers/policy.json /etc/containers/policy.json`"
		exit 1
	}
	try {
		cp /usr/etc/containers/policy.json /etc/containers/policy.json
	} catch {
		print "firstboot: failed to reset container policy.json file!"
		print "firstboot: couldn't copy the default policy.json"
  		print "firstboot: re-run with `sudo systemctl start reset-container-policy.service`"
        print "firstboot: or run `sudo cp /usr/etc/containers/policy.json /etc/containers/policy.json`"
        exit 1
	}
	print "firstboot: reset container policy.json file successfully!"
	systemctl disable --now reset-container-policy.service
	exit 0
}
