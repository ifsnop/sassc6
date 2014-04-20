#!/bin/bash
#
# monitord     monitord.py
#
# chkconfig:   - 85 15
# description: Secure, fast, compliant and very flexible monitor

### BEGIN INIT INFO
# Provides: monitord
# Required-Start: $local_fs $network
# Required-Stop: $local_fs $network
# Default-Start:
# Default-Stop: 0 1 2 3 4 5 6
# Short-Description: Lightning fast monitord
# Description:       Secure, fast, compliant and very flexible monitor
### END INIT INFO

#
# processname: monitord.py
# config: none
# pidfile: /var/run/monitord.pid

# Source function library.
. /etc/init.d/functions
 
# See how we were called.
  
prog="monitord"

start() {
	
#	if [[ ! -L /tmp/s ]]; then 
#	    ln -fs /mnt/3t001/s/ /tmp/s
#	fi

	echo -n $"Starting $prog: "
        if [ -e /var/lock/$prog ]; then
	    if [ -e /var/run/${prog}.pid ] && [ -e /proc/`cat /var/run/${prog}.pid` ]; then
		echo -n $"cannot start $prog: $prog is already running.";
		failure $"cannot start $prog: $prog already running.";
		echo
		return 1
	    fi
	fi
	#daemon "/usr/bin/python /software/sassc/scripts/sassc6/monitord.py --watch-path /home/eval/datos/incoming >> /var/log/monitord.log &"
	/software/sassc/scripts/sassc6/monitord.py --watch-path /home/eval/datos/incoming >> /var/log/monitord.log 2>&1 &
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch /var/lock/${prog};
	return $RETVAL
}

stop() {
	echo -n $"Stopping $prog: "
        if [ ! -e /var/lock/${prog} ]; then
	    echo -n $"cannot stop ${prog}: $prog is not running."
	    failure $"cannot stop ${prog}: $prog is not running."
	    echo
	    return 1;
	fi
	kill -9 `cat /var/run/${prog}.pid`
	RETVAL=$?
	success $"OK"
	echo
	rm -f /var/lock/${prog} 2> /dev/null;
	rm -f /var/run/${prog}.pid 2> /dev/null;
	return $RETVAL
}	

rhstatus() {
	status $prog
}	

restart() {
  	stop
	start
}	

case "$1" in
  start)
  	start
	;;
  stop)
  	stop
	;;
  restart)
  	restart
	;;
  reload)
  	restart
	;;
  status)
  	rhstatus
	;;
  condrestart)
  	[ -f /var/lock/${prog} ] && restart || :
	;;
  *)
	echo $"Usage: $0 {start|stop|status|reload|restart|condrestart}"
	exit 1
esac
