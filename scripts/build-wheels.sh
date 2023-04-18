#!/bin/sh

# See: https://stackoverflow.com/a/4774063
ROOT_DIR="$(dirname "$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )" )"

# POSIX compliant method for 'pipefail':
fail=$(mktemp)

# Check if 'pyenv' is on the PATH:
pyenv=$(which pyenv || echo > "$fail")

if [ -s "$fail" ]; then
    rm "$fail"
    echo "The build-wheel script requires 'pyenv' to manage differnt Python versions."
    echo "See: https://github.com/pyenv/pyenv#installation"
    exit 1
fi

eval "$(${pyenv} init -)"

# Build the wheels
set -- "3.7" "3.8" "3.9" "3.10" "3.11"
for python_version in "$@"
do
    pyenv shell "${python_version}" || echo > "$fail"
    if [ -s "$fail" ]
    then
        >&2 echo "pyenv: install with \`pyenv install ${python_version}'"
        exit 1
    else
        echo "$(python --version)"
        python -m pip install -r "${ROOT_DIR}/requirements-ci.txt"
        python -m pipx run --spec build pyproject-build --wheel --outdir="${ROOT_DIR}/wheelhouselocal"
    fi
done

# Determine the platform
# AIX            'aix'
# Emscripten     'emscripten'
# Linux          'linux'
# WASI           'wasi'
# Windows        'win32'
# Windows/Cygwin 'cygwin'
# macOS          'darwin'
PLATFORM="$(python -c 'import sys; print(sys.platform)')"

# Delocate the wheels
mkdir -p "${ROOT_DIR}/wheelhouse"
case "${PLATFORM}" in
    'darwin')
        python -m pip install -r "${ROOT_DIR}/requirements-ci.txt"
        python -m pipx run --spec delocate delocate-wheel --wheel-dir="${ROOT_DIR}/wheelhouse" "${ROOT_DIR}/wheelhouselocal"/*.whl
    ;;
    'linux')
        LIBC="$(python -c 'import platform; print(platform.libc_ver()[1].replace(".","_"))')"
        ARCH="$(python -c 'import platform; print(platform.machine())')"
        python -m pip install -r "${ROOT_DIR}/requirements-ci.txt"
        python -m pipx run auditwheel repair --wheel-dir="${ROOT_DIR}/wheelhouse" --plat="manylinux_${LIBC}_${ARCH}" "${ROOT_DIR}/wheelhouselocal"/*.whl
    ;;
    'win32')
        # 03-04-2023:
        # At the moment, delvewheel does not copy wheels if there is nothing to delocate,
        # which means that we cannot simply run it to future-proof our builds. Therefore,
        # we simply copy the wheels from wheelhouselocal to wheelhouse.
        cp "${ROOT_DIR}/wheelhouselocal"/*.whl "${ROOT_DIR}/wheelhouse/"
    ;;
esac
echo "The built wheels are located in ${ROOT_DIR}/wheelhouse"