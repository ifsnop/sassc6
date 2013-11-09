#!/usr/bin/env python

""" monitord.py - Starts automatic SASS-C processes when new files are written."""

__author__ = "Diego Torres"
__copyright__ = "Copyright (C) 2013 Diego Torres <diego dot torres at gmail dot com>"

# Requires Python >= 2.7

import functools
import sys, os
import statvfs                  # free space on partition
import time
import pprint
import datetime
import sys, getopt              # command line arguments
import ctypes
import platform                 # get_free_space_bytes()
import re                       # regexp
from stat import *              # interface to stat.h (get filesize, owner...)
from math import log            # format_size()
import pyinotify

config = { 'free_bytes_limit' : 1024*1024*1024*5,
    'recursive' : False,
    'temp_path' : '/tmp',
    'watch_path' : './',
    'self': 'monitord.py'
    }

valid_extensions = [ '.gps', '.sgps', '.bz2', '.ast', '.sast' ]

class Counter(object):
    def __init__(self):
        self.count = 0
    def plusone(self):
        self.count += 1

class EventHandler(pyinotify.ProcessEvent):
    def process_IN_CLOSE_WRITE(self,event):
        #<Event dir=False mask=0x8 maskname=IN_CLOSE_WRITE name=q.qw11 path=/tmp/l pathname=/tmp/l/q.qw11 wd=4 >
        #sys.stdout.write(formatTime() + pprint.pformat(event) + '\n')
        stat = os.stat(event.pathname)
        file = { 'size' : stat.st_size,
            'name' : event.name,
            'path' : event.path,
            'pathname' : event.pathname,
            'extension' : os.path.splitext(event.pathname)[1]
        }
        if not S_ISREG(stat.st_mode):
            return False

        if file['extension'] not in valid_extensions:
            print '{0} ? Not recognized extension: filename({1}) filesize({2}) extension({3})'\
                .format(format_time(), file['name'], format_size(file['size']), file['extension'])
            return False

        ret = check_free_space([config['watch_path'], config['temp_path']], config['free_bytes_limit'])
        if isinstance(ret, basestring):
            print '{0} ! ({1}) has less than {2} free'.format(format_time(), ret, format_size(config['free_bytes_limit']))
            return False

        print '{0} > filename({1}) filesize({2}) extension({3})'\
                .format(format_time(), file['name'], format_size(file['size']), file['extension'])

        if file['extension'] == '.bz2':
            print '{0} + ({1}) is a bz2 compressed file'.format(format_time(), file['name'])
        elif file['extension'] == '.gps':
            print '{0} + ({1}) is an operational recording file'.format(format_time(), file['name'])
        elif file['extension'] == '.sgps':
            print '{0} + ({1}) is a mode s recording file'.format(format_time(), file['name'])

        #p = re.compile(r"re.match("(\d+)-(\S+)-(\d+)", "213-cen-890").groups()", re.IGNORECASE)
        filename_extracted = re.match("(\d+)-(\S+)-(\d+)", file['name']).groups()
        if filename_extracted is None:
            print "{0} ! ({1}) can't be parsed as a valid filename)"\
                .format(format_time(), file['name'])
            return False

        pprint.pprint(filename_extracted)

        return True

def format_time():
    t = datetime.datetime.now()
    s = t.strftime('%Y-%m-%d %H:%M:%S.%f')
    tail = s[-7:]
    f = str('%0.3f' % round(float(tail),3))[2:]
    return '%s.%s' % (s[:-7], f)

def format_size(num):
    """Human friendly file size"""
    unit_list = zip(['bytes', 'kB', 'MB', 'GB', 'TB', 'PB'], [0, 0, 1, 2, 2, 2])
    if num > 1:
        exponent = min(int(log(num, 1024)), len(unit_list) - 1)
        quotient = float(num) / 1024**exponent
        unit, num_decimals = unit_list[exponent]
        format_string = '{:.%sf} {}' % (num_decimals)
        return format_string.format(quotient, unit)
    if num == 0:
        return '0 bytes'
    if num == 1:
        return '1 byte'

def get_free_space_bytes(folder = './'):
    """ Return folder/drive free space (in bytes) """
    folder = str(folder)
    if platform.system() == 'Windows':
        free_bytes = ctypes.c_ulonglong(0)
        ctypes.windll.kernel32.GetDiskFreeSpaceExW(ctypes.c_wchar_p(folder), None, None, ctypes.pointer(free_bytes))
        return free_bytes.value
    else:
        f = os.statvfs(folder)
        return f[statvfs.F_BAVAIL] * f[statvfs.F_FRSIZE]

def check_free_space(paths, free_bytes_limit):
    for path in paths:
        if get_free_space_bytes(path)<free_bytes_limit:
            return path
    return True

def on_loop(notifier, counter):
    """ Dummy function called after each event loop """
    #if counter.count > 49:
    #    # Loops 49 times then exits.
    #    sys.stdout.write("Exit\n")
    #    notifier.stop()
    #    sys.exit(0)
    #else:
    #    sys.stdout.write("Loop %d\n" % counter.count)
    #    counter.plusone()
    time.sleep(1)

def main(argv):
    def usage():
        print 'usage: ', argv[0], '[-h|--help]'
        print '                 [-l|--limit]'
        print '                 [-r|--recursive]'
        print '                 [-t|--temp-path <path>]'
        print '                 -w|--watch-path <path>'
        print
        print 'Starts automatic SASS-C processes when new files are written'
        print
        print ' -l, --limit              minimum free space in watch & temp directories in  bytes'
        print '                          defaults to', format_size(config['free_bytes_limit'])
        print ' -r, --recursive          descent into subdirectories'
        print '                          defaults to', str(config['recursive'])
        print ' -t, --temp-path <path>   temporary path used to process new file files'
        print "                          defaults to '", config['temp_path'], "'"
        print ' -w, --watch-path <path>  where to look for new files'
        print "                          defaults to '", config['watch_path'], "'"

    try:
        opts, args = getopt.getopt(argv[1:], 'hl:rt:w:', ['help', 'limit=', 
            'recursive', 'temp-path=', 'watch-path='])
    except getopt.GetoptError:
        usage()
        sys.exit(2)
    for opt,arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit()
        elif opt in ('-l', '--limit'):
            config['free_bytes_limit'] = float(arg)
        elif opt in ('-r', '--recursive'):
            config['recursive'] = True
        elif opt in ('-t', '--temp-path'):
            config['temp_path'] = os.path.abspath(arg)
        elif opt in ('-w', '--watch-path'):
            config['watch_path'] = os.path.abspath(arg)

    config['self'] = argv[0]

    print '{0} > {1} init'.format(format_time(), config['self'])
    print '{0} > options: limit({1})'.format(format_time(), format_size(config['free_bytes_limit']))
    print '{0} > options: recursive({1})'.format(format_time(), config['recursive'])
    print '{0} > options: temp_path({1}) free_bytes({2})'.format(format_time(), config['temp_path'], format_size(get_free_space_bytes(config['temp_path'])))
    print '{0} > options: watch_path({1}) free_bytes({2})'.format(format_time(), config['watch_path'], format_size(get_free_space_bytes(config['watch_path'])))

    ret = check_free_space([config['watch_path'], config['temp_path']], config['free_bytes_limit'])
    if isinstance(ret, basestring):
        print '{0} ! ({1}) has less than {2} bytes'.format(format_time(), ret, format_size(config['free_bytes_limit']))
        sys.exit(3)

    wm = pyinotify.WatchManager()
    notifier = pyinotify.Notifier(wm, EventHandler())
    wm.add_watch(config['watch_path'], pyinotify.IN_CLOSE_WRITE, rec=config['recursive'], auto_add=config['recursive'])
    on_loop_func = functools.partial(on_loop, counter=Counter())
    try:
        notifier.loop(daemonize=False, callback=on_loop_func,
            pid_file="/var/run/{config['self']}", stdout='/tmp/stdout.txt')
    except pyinotify.NotifierError, err:
        print >> sys.stderr, err

    return

if __name__ == "__main__":
    main(sys.argv)

"""
# using shell commands, getting output
from subprocess import PIPE, Popen

def free_volume(filename):
    #Find amount of disk space available to the current user (in bytes)
    #   on the file system containing filename.
    stats = Popen(["df", "-Pk", filename], stdout=PIPE).communicate()[0]
    return int(stats.splitlines()[1].split()[3]) * 1024

http://stackoverflow.com/questions/89228/calling-an-external-command-in-python

from subprocess import call
call(["ls", "-l"])

The advantage of subprocess vs system is that it is more flexible (you can get the stdout, stderr, the "real" status code, better error handling, etc...). I think os.system is deprecated, too, or will be:

http://docs.python.org/library/subprocess.html#replacing-older-functions-with-the-subprocess-module

For quick/dirty/one time scripts, os.system is enough, though.

"""
