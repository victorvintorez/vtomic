#!/usr/bin/env nu

def main [] {
    print "firstboot: removing setup user..."
    try {
        userdel -r setup
    } catch {
        print "firstboot: failed to remove setup user!"
        print "firstboot: user deletion failed"
        print "firstboot: re-run with `sudo systemctl start remove-setup-user.service`"
        print "firstboot: or run `sudo userdel -r setup`"
        exit 1
    }
    print "firstboot: removed setup user successfully!"
    systemctl disable --now remove-setup-user.service
    exit 0
}
