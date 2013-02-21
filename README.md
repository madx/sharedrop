ShareDrop
=========

ShareDrop is a system that eases file sharing on Linux, provided you've got
your own server to store the files.

It works by monitoring a folder for file creation or modification and by
automatically copying these files to your web server through an `sshfs` mount.


Requirements
------------

* bash (tested with 4.2.42)
* sshfs (tested with 2.4 on FUSE 2.9.2)
* sha1sum (tested with the version from GNU coreutils 8.21)
* inotify-tools (tested with 3.14)
* notify-send (tested with the version from libnotify 0.7.5)
* A web server

Setup
-----

ShareDrop needs some (quite easy) setup.

1. Define a VirtualHost (or equivalent) on your Web server that allows serving
   files from a given directory
2. Write a config file for ShareDrop (see below)
3. Run `sharedrop.sh`
4. Drop files in the folder you launched ShareDrop in
5. Wait for the notification giving you an URL for your file

Persistent setup
----------------

You may also want to automatically run ShareDrop on session start. You can give
a path to ShareDrop to monitor as the first argument of the command. This should
ease setting up your session manager.

Configuration
-------------

ShareDrop is configured through a `config.sh` file in a standard configuration
folder (if you haven't tweaked `$XDG_CONFIG_HOME` then it's likely to be in
`$HOME/.config/sharedrop/`). This file must define two bash variables:

  * `$REMOTE`: an `sshfs` remote mount specification (such as
    `example.com:public_html/`)
  * `$BASE_URL`: the URL for the VirtualHost you configured in your web server
    (e.g.: `http://example.com/share/`)
