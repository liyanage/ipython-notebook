#!/usr/bin/env python

import os
import sys
import subprocess

def library_imports_for_file(path):
    output = subprocess.check_output(['otool', '-L', path])
    return [line.strip().split()[0] for line in output.splitlines()[1:]]

def is_system_or_embedded_path(path):
    for prefix in ['/System/Library/Frameworks/', '/usr/lib/', '@']:
        if path.startswith(prefix):
            return True
    return False

def non_system_imports_for_file(path):
    return [item for item in library_imports_for_file(path) if not is_system_or_embedded_path(item)]

def process_file(path):
    for item in non_system_imports_for_file(path):
        basename = os.path.basename(item)
        rpath_name = os.path.join('@rpath', basename)
        cmd = 'install_name_tool -change {} {} "{}"'.format(item, rpath_name, path)
        print cmd
        subprocess.check_call(cmd, shell=True)

for dirpath, dirnames, filenames in os.walk(sys.argv[1]):
    for filename in filenames:
        if not (filename.endswith('.so') or filename.endswith('.dylib')):
            continue
        process_file(os.path.join(dirpath, filename))

