# DragonFly BSD Builder

This project builds the DragonFly BSD VM image for the
[cross-platform-actions/action](https://github.com/cross-platform-actions/action)
GitHub action. The image contains a standard DragonFly BSD installation. It will
install the following packages:

* bash
* curl
* rsync
* sudo

Except for the root user, there's one additional user, `runner`, which is the
user that will be running the commands in the GitHub action. This user is
allowed use `sudo` without a password.

## Architectures and Versions

The following architectures and versions are supported:

| Version | x86-64 |
|---------|--------|
| 6.4.2   | ✓      |

## Building Locally

### Prerequisite

* [Packer](https://www.packer.io) 1.15.1 or later
* [QEMU](https://qemu.org)

### Building

1. Clone the repository:
    ```
    git clone https://github.com/cross-platform-actions/dragonflybsd-builder
    cd dragonflybsd-builder
    ```

2. Run `build.sh` to build the image:
    ```
    ./build.sh <version> <architecture>
    ```
    Where `<version>` and `<architecture>` are the any of the versions or
    architectures available in the above table.

The above command will build the VM image and the resulting disk image will be
at the path: `output/dragonflybsd-6.4.2-x86-64.qcow2`.

## Additional Information

The qcow2 format is chosen because unused space doesn't take up any space on
disk, it's compressible and easily converts the raw format.
