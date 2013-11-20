#!/bin/sh

set -e
set -x


# pylab needs a fortran compiler
export PATH=$PATH:/usr/local/bin # presumably where gfortran is
if ! type gfortran; then
    echo Please install gfortran, for example from http://cran.r-project.org/bin/macosx/tools/
    exit 1
fi

if ! [ -e /usr/local/lib/libgfortran.2.dylib ] ; then
    echo libgfortran.2.dylib not found in /usr/local/lib, please install gfortran, for example from http://cran.r-project.org/bin/macosx/tools/
    exit 1
fi

# This is a temporary directory to install the base tools that
# we need to build the virtualenv. It is not the virtualenv itself
# and it is not included in the final product.
BUILD_PYTHONPATH="$DERIVED_FILE_DIR"/build-python-lib
export PYTHONPATH="$BUILD_PYTHONPATH"
export PATH="$BUILD_PYTHONPATH":"$PATH"
mkdir -p "$BUILD_PYTHONPATH"

# We need pip and virtualenv to build the virtualenv
if ! pip freeze >/dev/null 2>&1; then
    echo Installing pip...
    easy_install --install-dir="$BUILD_PYTHONPATH" pip
fi


if ! type virtualenv >/dev/null 2>&1; then
    echo Installing virtualenv...
    easy_install --install-dir="$BUILD_PYTHONPATH" virtualenv
	VIRTUALENV="$BUILD_PYTHONPATH"/virtualenv
else
	VIRTUALENV=virtualenv
fi

# This is the location of the virtualenv. It is included
# in the final product.
VIRTUALENV_DIR="$SCRIPT_OUTPUT_FILE_0"
rm -rf "$VIRTUALENV_DIR"
mkdir -p "$VIRTUALENV_DIR"

cd "$VIRTUALENV_DIR"

# Initialize the virtualenv
if ! [ -e .Python ]; then
    "$VIRTUALENV" --no-site-packages .
    #"$VIRTUALENV" --system-site-packages .

    # add an @rpath entry to the python binary so that the
    # .so extensions it loads can find our custom-built,
    # bundled libraries such as libpng and libfreetype
    install_name_tool -add_rpath @executable_path/../../../Frameworks/ "$VIRTUALENV_DIR"/bin/python

    # add other, temporary ones so it finds the libraries also during the build, for unit tests
    install_name_tool -add_rpath "$SCRIPT_INPUT_FILE_1"/lib "$VIRTUALENV_DIR"/bin/python
    install_name_tool -add_rpath "$SCRIPT_INPUT_FILE_2"/lib "$VIRTUALENV_DIR"/bin/python
fi


# Activate the virtualenv and then use pip to install various
# required modules that we want to include.
. bin/activate

export CC=clang
export CXX=clang
#export FFLAGS=-ff2c

# Install modules - unit testing
pip install nose

# Install modules - scientific
pip install numpy > "$CONFIGURATION_TEMP_DIR"/install-numpy.log
#python <<EOF
#import numpy
#numpy.test('full')
#EOF

if ! pip install scipy > "$CONFIGURATION_TEMP_DIR"/install-scipy.log; then
    echo scipy installation failed:
    cat "$CONFIGURATION_TEMP_DIR"/install-scipy.log
    exit 1
fi

#python <<EOF
#import scipy
#scipy.test('full')
#EOF

# Install modules - matplotlib
CFLAGS="-I$SCRIPT_INPUT_FILE_1/include -I$SCRIPT_INPUT_FILE_2/include/freetype2 -I$SCRIPT_INPUT_FILE_2/include"
LDFLAGS="-framework ApplicationServices -L$SCRIPT_INPUT_FILE_1/lib -L$SCRIPT_INPUT_FILE_2/lib"
CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" pip install matplotlib

# Install modules - scikit-learn
pip install scikit-learn

# Install modules - scikit-image
pip install Cython
pip install scikit-image

if ! pip install bokeh > "$CONFIGURATION_TEMP_DIR"/install-bokeh.log; then
    echo bokeh installation failed:
    cat "$CONFIGURATION_TEMP_DIR"/install-bokeh.log
    exit 1
fi

# Install modules - prerequisites for IPython Notebook
easy_install pyzmq
pip install Jinja2
pip install tornado

if ! pip install pymc > "$CONFIGURATION_TEMP_DIR"/install-pymc.log; then
    echo pymc installation failed:
    cat "$CONFIGURATION_TEMP_DIR"/install-pymc.log
    exit 1
fi

pip install pandas
#nosetests pandas

# Install iPython
IPYTHON_DISTRIBUTION="$DERIVED_FILE_DIR"/ipython
if ! [ -e "$IPYTHON_DISTRIBUTION" ]; then
    curl -L -o ipython-distribution.zip https://github.com/ipython/ipython/releases/download/rel-1.1.0/ipython-1.1.0.zip
    unzip -d "$IPYTHON_DISTRIBUTION" ipython-distribution.zip
    rm ipython-distribution.zip
fi
pip install "$IPYTHON_DISTRIBUTION"/ipython-*

# Download and embed MathJax, so that the app doesn't
# have to load it from the CDN at runtime.
python <<EOF
from IPython.external.mathjax import install_mathjax
install_mathjax()
EOF

rsync -aP "$SCRIPT_INPUT_FILE_3"/lib/python2.7/ "$VIRTUALENV_DIR"/lib/python2.7/

# Rewrite some scripts to make them relocatable, so that
# users can move around the .app wrapper.
#"$VIRTUALENV" --relocatable "$VIRTUALENV_DIR"

# Get rid of any .pyc bytecode files.
find "$VIRTUALENV_DIR" -name '*.pyc' -delete

# remove temporary rpath values
install_name_tool -delete_rpath "$SCRIPT_INPUT_FILE_1"/lib "$VIRTUALENV_DIR"/bin/python
install_name_tool -delete_rpath "$SCRIPT_INPUT_FILE_2"/lib "$VIRTUALENV_DIR"/bin/python

# undo the effect of the '--no-site-packages' option used during virtualenv creation
rm "$VIRTUALENV_DIR"/lib/python2.7/no-global-site-packages.txt

# rewrite dyld references pointing to non-system locations to use @rpath
"$SRCROOT/IPython Notebook/build-support/rewrite-dylib.py" "$VIRTUALENV_DIR"

touch "$VIRTUALENV_DIR"


