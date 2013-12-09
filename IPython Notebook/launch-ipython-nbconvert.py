import os; activate_this=os.path.join(os.path.dirname(os.path.realpath(__file__)), 'activate_this.py'); execfile(activate_this, dict(__file__=activate_this)); del os, activate_this

__requires__ = 'ipython==1.1.0'
import sys
import os
from pkg_resources import load_entry_point

virtualenv_path, input_document_path = sys.argv

sys.argv = ['ipython', 'nbconvert', '--to', 'html', '--stdout', input_document_path]
resource_dir = os.path.realpath(__file__)
for i in range(3):
	resource_dir = os.path.dirname(resource_dir)
mimetype_path = '/'.join([resource_dir, 'mime.types'])
import mimetypes
mimetypes.knownfiles = [mimetype_path]

entry_point = load_entry_point('ipython==1.1.0', 'console_scripts', 'ipython')
result = entry_point()
sys.exit(result)

#
#
#
#VIRTUALENV_PATH="$1"
#INPUT_DOCUMENT_PATH="$2"
#
#set > $TMPDIR/nbconvert.sh.log
#echo xxx >> $TMPDIR/nbconvert.sh.log
#env >> $TMPDIR/nbconvert.sh.log
#echo xxx >> $TMPDIR/nbconvert.sh.log
#echo $* >> $TMPDIR/nbconvert.sh.log
#
##. "$VIRTUALENV_PATH"/bin/activate
#
#env > $TMPDIR/nbconvert.sh.log2
#
#export PATH=$PATH:"$VIRTUALENV_PATH"/bin
#"$VIRTUALENV_PATH"/bin/ipython nbconvert --to html "$INPUT_DOCUMENT_PATH" --stdout
#
##--- investigate how activate is run for server task, and if VIRTUALENV_PATH in bin/activate
##needs to be rewritten when embedded into package, or better can be made dynamic
