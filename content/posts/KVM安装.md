---
title: "KVM安装"
date: 2020-02-29T15:12:41+08:00
tags: [linux, KVM]
draft: false
---

> 本篇总结自[how-to-install-virtual-machine-manager-kvm-in-manjaro-and-arch-linux](https://www.fosslinux.com/2484/how-to-install-virtual-machine-manager-kvm-in-manjaro-and-arch-linux.htm).

## 检查硬件支持

```
LC_ALL=C lscpu | grep Virtualization
```

以上语句应当得到`Virtualization: VT-x`或者`Virtualization: AMD-V`的结果, 否则硬件不支持, 请前往BIOS设置虚拟化选项.

## 检查内核支持

运行`zgrep CONFIG_KVM /proc/config.gz`, 得到的结果应该是`CONFIG_KVM_INTEL`或者`CONFIG_KVM_AMD`的值为`m`或`y`. 以下是样例输出.

```
CONFIG_KVM_GUEST=y
# CONFIG_KVM_DEBUG_FS is not set
CONFIG_KVM_MMIO=y
CONFIG_KVM_ASYNC_PF=y
CONFIG_KVM_VFIO=y
CONFIG_KVM_GENERIC_DIRTYLOG_READ_PROTECT=y
CONFIG_KVM_COMPAT=y
CONFIG_KVM=m
CONFIG_KVM_INTEL=m
CONFIG_KVM_AMD=m
CONFIG_KVM_MMU_AUDIT=y
```

## 安装KVM(虚拟机管理器)

**第一步**: 运行以下命令来安装KVM和一些依赖

```
sudo pacman -S virt-manager qemu vde2 ebtables dnsmasq bridge-utils openbsd-netcat
```

注意以下两步要完成, 如果此时直接运行虚拟机管理器, 会得到`adduser: The group 'libvirtd’ does not exist`的错误.

**第二步**: 启用`libvirtd`服务

```
sudo systemctl enable libvirtd.service
```

**第三步**: 启动`libvirtd`服务

```
sudo systemctl start libvirtd.service
```