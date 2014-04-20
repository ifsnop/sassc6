SASSC6
======

General utilities and scripts to run headless evaluations on SASS-C.

monitord.py       Monitors incoming ftp directory and launches new evaluations.
monitord.sh       init.d script that launches monitord.py at system startup.

INSTALL
======

Just add monitord to init.d scripts:

~~~
# ln -s /software/sassc/scripts/sassc6/monitord.sh /etc/init.d/monitord.sh
# chkconfig -add monitord.sh
~~~

FAQ
======

Getting the message "No space left on device (ENOSPC)" when adding a new
watch.
From https://github.com/seb-m/pyinotify/wiki/Frequently-Asked-Questions

You must have reached your quota of watches, type:

~~~
sysctl -n fs.inotify.max_user_watches
~~~

to read your current limit and type:

~~~
sysctl -n -w fs.inotify.max_user_watches=16384
~~~

to increase it to 16384.
