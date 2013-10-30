#!/usr/bin/env python2.7

import os; activate_this=os.path.join(os.path.dirname(os.path.realpath(__file__)), 'activate_this.py'); execfile(activate_this, dict(__file__=activate_this)); del os, activate_this

# EASY-INSTALL-ENTRY-SCRIPT: 'ipython==1.1.0','console_scripts','ipython'
__requires__ = 'ipython==1.1.0'
import sys
from pkg_resources import load_entry_point

import os
port = os.environ['IPYTHON_NOTEBOOK_APP_PORT']
ipython_dir = os.environ['IPYTHON_NOTEBOOK_APP_IPYTHON_DIR']

extra_paths = os.environ.get('IPYTHON_NOTEBOOK_APP_EXTRA_PYTHONPATH')
if extra_paths:
    extra_paths = extra_paths.split(':')
    sys.path.extend(extra_paths)

# ipython help  notebook --help-all
sys.argv = ['ipython', 'notebook', '--pylab', 'inline', '--no-browser', '--port={}'.format(port), '--ipython-dir={}'.format(ipython_dir), '--notebook-dir={}'.format(ipython_dir)]

resource_dir = os.path.realpath(__file__)
for i in range(3):
	resource_dir = os.path.dirname(resource_dir)
mimetype_path = '/'.join([resource_dir, 'mime.types'])
import mimetypes
mimetypes.knownfiles = [mimetype_path]

# ensure the forked Python processes inherit our sys.path so they can find the embedded modules
os.environ['PYTHONPATH'] = os.pathsep.join(sys.path)

entry_point = load_entry_point('ipython==1.1.0', 'console_scripts', 'ipython')
result = entry_point()
sys.exit(result)

