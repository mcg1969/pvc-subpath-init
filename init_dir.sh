#!/bin/bash -e

# Persistent volume claim subPath initializer
# Michael Grant, Anaconda, Inc., November 2021
# License: CC0 https://creativecommons.org/share-your-work/public-domain/cc0/

# Motivation: when Kubernetes mounts a PVC with a non-empty subPath, it
# will create that subdirectory on the volume if it does not yet exist.
# Unfortunately, the resulting ownership and permissions are often not
# what the downstream container can accept. This script is designed to
# run within an initContainer given the same volumeMount, but *without*
# the subpath. It can then create the subdirectory and ensure that it
# has the proper permissions. More at this link:
# https://stackoverflow.com/questions/43544370/kubernetes-how-to-set-volumemount-user-group-and-file-permissions

# Example: consider a volumeMount:
# - name: test-mount
#   mountPath: /mount/point
#   subPath: sub/path
# This would be the initContainer template. We assume that the script is placed
# in the root directory of the container and its execute bit is set.
# - name: storage-permissions
#   image: <IMAGE_NAME>
#   volumeMounts:
#   - name: test-mount
#     mountPath: /mount/point
#   command: ["/init_dir.sh", "/mount/point", "sub/path"]

set -e
base_dir=$(echo /$1 | sed -E 's@/+$@@;s@//+@/@g')
full_dir=$(echo /$1/$2 | sed -E 's@/+$@@;s@//+@/@g')

echo "----------------------"
echo "Storage initialization"
echo "----------------------"
echo "Mount path: $base_dir"
echo "Full path: $full_dir"
echo "----------------------"

if [ ! -d $base_dir ]; then
    echo "* ERROR: mount path $base_dir does not exist"
    exit -1
fi

if [ ! -d $full_dir ]; then
    echo "- Attempting to create $full_dir"
    echo "> mkdir -p $full_dir"
    if ! mkdir -p "$full_dir" 2>&1 | sed 's@^@| @'; then
        echo "* ERROR: directory could not be created"
        exit -1
    fi
elif [ $full_dir = $base_dir ]; then
    echo "* NOTE: no subPath: permissions setting/testing only"
else
    echo "- Directory already exists"
fi

echo "> ls -ld $full_dir"
if ! ls -ld "$full_dir" 2>&1 | sed 's@^@| @'; then
    echo "* ERROR: could not list $full_dir"
    exit -1
fi

perms=$(stat -c '%a' $full_dir)
echo "- Permissions: $perms"
if [[ $perms != "775" && $perms != "2775" ]]; then
    echo "- Setting directory permissions with setgid"
    echo "> chmod 2775 $full_dir"
    if ! chmod 2775 $full_dir 2>&1 | sed 's@^@| @'; then
        echo "* WARNING: could not setgid; trying without."
        echo "> chmod 775 $full_dir"
        if ! chmod 775 $full_dir 2>&1 | sed 's@^@| @'; then
            echo "* ERROR: could not set permissions"
            exit -1
        fi
    fi
    perms=$(stat -c '%a' $full_dir)
    echo "- New permissions: $perms"
    if [[ $perms != "775" && $perms != "2775" ]]; then
        echo "* ERROR: permissions could not be set"
        exit -1
    fi
    echo "> ls -ld $full_dir"
    if ! ls -ld "$full_dir" 2>&1 | sed 's@^@| @'; then
        echo "* ERROR: could not list $full_dir"
        exit -1
    fi
fi

echo "- Testing writability"
echo "> touch $full_dir/.test_write"
if ! touch $full_dir/.test_write 2>&1 | sed 's@^@| @'; then
    echo "* ERROR: directory is not writable"
    exit -1
fi
echo "> rm $full_dir/.test_write"
if ! rm "$full_dir"/.test_write 2>&1 | sed 's@^@| @'; then
    echo "* ERROR: could not remove test file"
    exit -1
fi

echo "----------------------"
