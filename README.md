# Persistent volume claim subPath initializer
Michael Grant, Anaconda, Inc., November 2021

## Motivation

StackOverflow background [here](More at this link:
https://stackoverflow.com/questions/43544370/kubernetes-how-to-set-volumemount-user-group-and-file-permissions).

When a Kubernetes pod mounts a PVC with a non-empty subPath, it
will create that subdirectory on the volume if it does not yet exist.
Unfortunately, the resulting ownership and permissions are often not
what the downstream container can accept. This script is designed to
run within an initContainer given the same volumeMount, but *without*
the subpath. It can then create the subdirectory and ensure that it
has the proper permissions.

## Example

Consider this `volumeMount`:

```
- name: test-mount
  mountPath: /mount/point
  subPath: sub/path
```
  
An `initContainer` might look like this:

```
- name: storage-permissions
  image: <IMAGE_NAME>
  volumeMounts:
  - name: test-mount
    mountPath: /mount/point
  command: ["/init_dir.sh", "/mount/point", "sub/path"]
```

The image itself can be virtually any image; typically you would
re-use the pod's `container` image. The output looks something
like this:

```
----------------------
Mount path: /mount/path
Full path: /mount/path/sub/path
----------------------
- Attempting to create /mount/path/sub/path
> mkdir -p /mount/path/sub/path
> ls -ld /mount/path/sub/path
| drwxr-xr-x 2 1002 23456 4096 Dec  3 15:54 /mount/path/sub/path
- Permissions: 755
- Setting directory permissions with setgid
> chmod 2775 /persistence-v/persistence/projects
- New permissions: 2775
> ls -ld /persistence-v/persistence/projects
| drwxrwsr-x 2 1002 23456 4096 Dec  3 15:54 ls -ld /mount/path/sub/path
- Testing writability
> touch /mount/path/sub/path/.test_write
> rm /mount/path/sub/path/.test_write
----------------------
```

## Public domain / no warranty

This entire repository has been released to the public domain;
or more precisely, the [CC0 1.0 Universal]() license.

Please feel free to use this in any context, modified in any
way you choose, without attribution.

That said, this work is also entirely unsupported and comes
with no warranty. It works for me, and I do hope it works
for you!
