#!/usr/bin/env python

""" monitord.py - Starts automatic SASS-C processes when new files are written."""

__author__ = "Diego Torres"
__copyright__ = "Copyright (C) 2014 Diego Torres <diego dot torres at gmail dot com>"

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

config = { 'db_file' : None,
    'min_free_bytes' : 1024*1024*1024*5,
    'min_size_bytes' : 0,
    'max_size_bytes' : 1024*1024*1024,
    'recursive' : False,
    'temp_path' : '/tmp',
    'watch_path' : './',
    'self': 'monitord.py'
    }

valid_extensions = [ '.gps', '.sgps', '.bz2', '.ast', '.sast' ]

class EventHandler(pyinotify.ProcessEvent):
    def process_IN_DELETE(self, event):
        self.process(event)

    def process_IN_MOVED_TO(self, event):
        self.process(event)

    def process_IN_MOVED_FROM(self, event):
        self.process(event)

    def process_IN_CLOSE_WRITE(self, event):
        self.process(event)

    def process_IN_Q_OVERFLOW(self, event):
        print '{0} ! error overflow'\
            .format(format_time())
        return

    def process_default(self, event):
        return

    def process(self, event):
        #<Event dir=False mask=0x8 maskname=IN_CLOSE_WRITE name=q.qw11 path=/tmp/l pathname=/tmp/l/q.qw11 wd=4 >
        #sys.stdout.write(formatTime() + pprint.pformat(event) + '\n')
        stat = os.stat(event.pathname)
        file = { 'size' : stat.st_size,
            'nameext' : event.name,
            'path' : event.path,
            'pathnameext' : event.pathname,
            'name' : os.path.splitext(event.name)[0],
            'ext' : os.path.splitext(event.pathname)[1],
            'event' : event.maskname
        }

        print '{0} > filename({1}) filesize({2}) extension({3}) operation({4})'\
                .format(format_time(), file['nameext'], format_size(file['size']), \
                file['ext'], file['event'])

        print '{0} > filename({1}) sha1({2})'\
                .format(format_time(), file['nameext'], sha1_file(file['pathnameext']))

        if not S_ISREG(stat.st_mode):
            return False

        if file['size']<config['min_size_bytes']:
            print '{0} ? file size lower than ({1}): filename({2}) filesize({3}) extension({4})'\
                .format(format_time(), config['min_size_bytes'], file['nameext'], \
                format_size(file['size']), file['ext'])
            return False

        if file['size']>config['max_size_bytes']:
            print '{0} ? file size greater than ({1}): filename({2}) filesize({3}) extension({4})'\
                .format(format_time(), config['max_size_bytes'], file['nameext'], \
                format_size(file['size']), file['ext'])
            return False

        update_database(file['pathnameext'], file['event'])

        if file['ext'] not in valid_extensions:
            print '{0} ? not recognized extension: filename({1}) filesize({2}) extension({3})'\
                .format(format_time(), file['nameext'], format_size(file['size']), file['ext'])
            return False

        ret = check_free_space([config['watch_path'], config['temp_path']], config['min_free_bytes'])
        if isinstance(ret, basestring):
            print '{0} ! ({1}) has less than {2} free'.format(format_time(), ret, format_size(config['min_free_bytes']))
            return False

        print '{0} > filename({1}) filesize({2}) extension({3})'\
                .format(format_time(), file['nameext'], format_size(file['size']), file['ext'])

        if file['ext'] == '.bz2':
            print '{0} + ({1}) is a bz2 compressed file'.format(format_time(), file['nameext'])
        elif file['ext'] == '.gps':
            print '{0} + ({1}) is an operational recording file'.format(format_time(), file['nameext'])
        elif file['ext'] == '.sgps':
            print '{0} + ({1}) is a mode s recording file'.format(format_time(), file['nameext'])
        else:
            print '{0} + ({1}) is allowed but not action defined'.format(format_time(), file['nameext'])

        match = re.match("(\d+)-(\S+)-(\d+)", file['name'])
        if match is None:
            print "{0} ! ({1}) can't be parsed as a valid (yymmdd-conf-hhmmss) filename"\
                .format(format_time(), file['nameext'])

            # let try the other way
            match = re.match("(\d+)-(\d+)-(\S+)", file['name'])
            if match is None:
                print "{0} ! ({1}) can't be parsed as a valid (yymmdd-hhmmss-conf) filename"\
                    .format(format_time(), file['nameext'])
                return False

        filename_extracted = match.groups()
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
    unit_list = zip(['B', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi'], [0, 0, 1, 2, 2, 2])
    if num > 1:
        exponent = min(int(log(num, 1024)), len(unit_list) - 1)
        quotient = float(num) / 1024**exponent
        unit, num_decimals = unit_list[exponent]
        format_string = '{:.%sf}{}' % (num_decimals)
        return format_string.format(quotient, unit)
    if num == 0 or num == 1:
        return str(num) + 'B'

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

def sha1_file(filename):
    import hashlib
    with open(filename, 'rb') as f:
        return hashlib.sha1(f.read()).hexdigest()

def update_database(file, action):

    print '{0} + file ({1}) with action ({2})'.format(format_time(), file, action)


def main(argv):
    def usage():
        print 'usage: ', argv[0], '[-h|--help]'
        print '                 [-f|--min-free]'
        print '                 [-s|--min-size]'
        print '                 [-m|--max-size]'
        print '                 [-r|--recursive]'
        print '                 [-t|--temp-path <path>]'
        print '                 -w|--watch-path <path>'
        print
        print 'Starts automatic SASS-C processes when new files are written'
        print
        print ' -d, --db-file            sqlite path to store sha1 signatures'
        print '                          default to \'' + str(config['db_file']) + '\''
        print ' -f, --min-free           minimum free space in watch & temp directories in bytes'
        print '                          defaults to', format_size(config['min_free_bytes'])
        print ' -s, --min-size           minimum file size to react, in bytes'
        print '                          defaults to', format_size(config['min_size_bytes'])
        print ' -m, --max-size           maximum file size to react, in bytes'
        print '                          defaults to', format_size(config['max_size_bytes'])
        print ' -r, --recursive          descent into subdirectories'
        print '                          defaults to', str(config['recursive'])
        print ' -t, --temp-path <path>   temporary path used to process new files'
        print '                          defaults to \'' + config['temp_path'] + '\''
        print ' -w, --watch-path <path>  where to look for new files'
        print '                          defaults to \'' + config['watch_path'] + '\''

    try:
        opts, args = getopt.getopt(argv[1:], 'hd:f:s:m:rt:w:', ['help',
            'db-file=', 'min-free=', 'min-size=', 'max-size=', 'recursive',
            'temp-path=', 'watch-path='])
    except getopt.GetoptError:
        usage()
        sys.exit(2)
    for opt,arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit()
        elif opt in ('-d', '--db-file'):
            config['db_file'] = arg
        elif opt in ('-f', '--min-free'):
            config['min_free_bytes'] = float(arg)
        elif opt in ('-s', '--min-size'):
            config['min_size_bytes'] = float(arg)
        elif opt in ('-m', '--max-size'):
            config['max_size_bytes'] = float(arg)
        elif opt in ('-r', '--recursive'):
            config['recursive'] = True
        elif opt in ('-t', '--temp-path'):
            config['temp_path'] = os.path.abspath(arg)
        elif opt in ('-w', '--watch-path'):
            config['watch_path'] = os.path.abspath(arg)

    config['self'] = argv[0]

    print '{0} > {1} init'.format(format_time(), config['self'])
    print '{0} > options: db-file({1})'.format(format_time(), config['db_file'])
    print '{0} > options: min-free({1})'.format(format_time(), format_size(config['min_free_bytes']))
    print '{0} > options: min-size({1})'.format(format_time(), format_size(config['min_size_bytes']))
    print '{0} > options: max-size({1})'.format(format_time(), format_size(config['max_size_bytes']))
    print '{0} > options: recursive({1})'.format(format_time(), config['recursive'])
    print '{0} > options: temp-path({1}) free_bytes({2})'.format(format_time(), config['temp_path'], format_size(get_free_space_bytes(config['temp_path'])))
    print '{0} > options: watch-path({1}) free_bytes({2})'.format(format_time(), config['watch_path'], format_size(get_free_space_bytes(config['watch_path'])))

    ret = check_free_space([config['watch_path'], config['temp_path']], config['min_free_bytes'])
    if isinstance(ret, basestring):
        print '{0} ! ({1}) has less than {2} bytes'.format(format_time(), ret, format_size(config['min_free_bytes']))
        sys.exit(3)
    wm = pyinotify.WatchManager()
    notifier = pyinotify.Notifier(wm, EventHandler())
    wm.add_watch(config['watch_path'], 
        pyinotify.IN_CLOSE_WRITE | pyinotify.IN_MOVED_TO | pyinotify.IN_MOVED_FROM |
        pyinotify.IN_DELETE | pyinotify.IN_Q_OVERFLOW,
        rec=config['recursive'], auto_add=config['recursive'])
    #on_loop_func = functools.partial(on_loop, counter=Counter())
    try:
        # disabled callback counter from example, not needed
        #notifier.loop(daemonize=False, callback=on_loop_func,
        #    pid_file="/var/run/{config['self']}", stdout='/tmp/stdout.txt')
        notifier.loop(daemonize=False, callback=None,
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
"""
class Counter(object):
    def __init__(self):
        self.count = 0
    def plusone(self):
        self.count += 1
"""
"""
def on_loop(notifier, counter):
    # Dummy function called after each event loop
    if counter.count > 49:
        # Loops 49 times then exits.
        sys.stdout.write("Exit\n")
        notifier.stop()
        sys.exit(0)
    else:
    sys.stdout.write("Loop %d\n" % counter.count)
    counter.plusone()
    time.sleep(2)
"""