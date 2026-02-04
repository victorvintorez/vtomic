#!/usr/bin/env nu

def main [] {
	dnf install -y anaconda-live libblockdev-btrfs

	cp files/installer/installer.ks /kickstart.ks
}
