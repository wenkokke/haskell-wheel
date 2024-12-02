#!/bin/sh

# Get configuration from Tox
# 2024-04-16: The substitution for '{env_python}' and other environment variables no longer appears to work.
python="python"
package_root="${package_root:-"$(dirname "$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )" )"}"
dist_dir="${package_root}/dist"
dist_tmp_dir="${package_root}/dist/_tmp"

# Get target platform;
platform=$("${python}" -c 'import sys; print(sys.platform)')

# Check if dependencies are available:

# Check if cabal is available:
env_cabal="$(which cabal)"
if [ "${env_cabal}" = '' ]
then
    echo "${0} requires 'cabal'"
    echo "See: https://cabal.readthedocs.io/en/stable/"
    exit 1
fi

# Check if build is available:
has_build=$("${python}" -c 'import importlib.util; print(importlib.util.find_spec("build") is not None)')
if [ "${has_build}" = 'False' ]
then
    echo "${0} requires 'build'"
    echo "See: https://pypi.org/project/build/"
    exit 1
fi

# Check if platform-specific dependencies are available:
case "${platform}" in
    'linux')
        # Check if auditwheel is available:
        has_auditwheel=$("${python}" -c 'import importlib.util; print(importlib.util.find_spec("auditwheel") is not None)')
        if [ "${has_auditwheel}" = 'False' ]
        then
            echo "${0} requires 'auditwheel'"
            echo "See: https://pypi.org/project/auditwheel/"
            exit 1
        fi
    ;;
    'darwin')
        # Check if delocate is available:
        has_delocate=$("${python}" -c 'import importlib.util; print(importlib.util.find_spec("delocate") is not None)')
        if [ "${has_delocate}" = 'False' ]
        then
            echo "${0} requires 'delocate'"
            echo "See: https://pypi.org/project/delocate/"
            exit 1
        fi
    ;;
esac

# Update the hackage package list
"${env_cabal}" v2-update

# Build the wheel
"${python}" -m build --wheel --outdir "${dist_tmp_dir}" "${package_root}"

# Delocate the wheel
case "${platform}" in
    'linux')
        # Repair wheel with auditwheel
        machine="$("${python}" -c 'import platform; print(platform.machine())')"
        libc_ver="$("${python}" -c 'import platform; print(platform.libc_ver()[1].replace(".","_"))')"
        if [ "${libc_ver}" = "" ]; then
            musl_ver="$("${python}" -c 'import sys; import packaging._musllinux; musl_ver=packaging._musllinux._get_musl_version(sys.executable); musl_ver and print(f"{musl_ver.major}_{musl_ver.minor}")')"
            plat="musllinux_${musl_ver}_${machine}"
        else
            plat="manylinux_${libc_ver}_${machine}"
        fi
        auditwheel repair --wheel-dir "${dist_dir}" --plat "${plat}" "${dist_tmp_dir}"/*.whl
    ;;
    'darwin')
        # Repair wheel with delocate-wheel
        delocate-wheel --wheel-dir "${dist_dir}" "${dist_tmp_dir}"/*.whl
    ;;
    *)
        mkdir -p "${dist_dir}"
        cp "${dist_tmp_dir}"/*.whl "${dist_dir}"/
    ;;
esac
echo "The built wheel is located in ${dist_dir}"
