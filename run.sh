#!/bin/bash

qemu-system-x86_64 \
  -boot strict=off \
  -machine type=pc \
  -name dragonflybsd-6.4.2-x86-64.qcow2 \
  -monitor none \
  -device virtio-scsi-pci \
  -device scsi-hd,drive=drive0,bootindex=0 \
  -device virtio-net,netdev=user.0 \
  -bios bios-256k.bin \
  -m 4096M \
  -smp 2 \
  -cpu qemu64 \
  -accel hvf \
  -accel kvm \
  -accel tcg \
  -drive if=none,file=output/dragonflybsd-6.4.2-x86-64.qcow2,id=drive0,cache=writeback,discard=ignore,format=qcow2 \
  -netdev user,id=user.0,hostfwd=tcp::2433-:22,ipv6=off \
  -vnc 127.0.0.1:42 \
  -display cocoa \
  -nographic
