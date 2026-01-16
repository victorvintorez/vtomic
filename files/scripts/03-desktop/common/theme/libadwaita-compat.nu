#!/usr/bin/env nu

sudo mkdir -p /etc/skel/.config/gtk-4.0
sudo ln -s /usr/share/themes/Orchis-Dark/gtk-4.0/gtk.css /etc/skel/.config/gtk-4.0/gtk.css
sudo ln -s /usr/share/themes/Orchis-Dark/gtk-4.0/gtk-dark.css /etc/skel/.config/gtk-4.0/gtk-dark.css
sudo ln -s /usr/share/themes/Orchis-Dark/gtk-4.0/assets /etc/skel/.config/gtk-4.0/assets
