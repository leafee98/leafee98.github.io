---
title: 树莓派Arch Base系统无头配置wifi
date: 2020-02-06 19:31:00 +0800
layout: post
categories: linux
tags: [raspi, linux]
---

## 开门见山

本文讲解了基于ArchLinux的发行版在没有显示器/键盘/网线, 只有读卡器/一台电脑/WIFI的情况下配置无线连接的事. 细节讲解在后边.

在我为了无头配置wifi而焦头烂额的时候, 我终于看到了[这么一篇博文](https://ladvien.com/installing-arch-linux-raspberry-pi-zero-w/), 而博文中有这样一番代码.

```
#!/bin/sh

set -e

if [[ $# -ne 3 ]] ; then
   echo "Usage: $0 </dev/disk> <ssid> <passphase>"
   exit 1
fi

DISK="$1"
SSID="$2"
PASS="$3"

if [[ ! -b "${DISK}" ]] ; then
   echo "Not a block device: ${DISK}"
   exit 1
fi

if [[ "${USER}" != "root" ]] ; then
   echo "Must run as root."
   exit 1
fi

echo Mounting
mkdir root
mount "${DISK}2" root

cat << EOF >> root/etc/systemd/network/wlan0.network
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

wpa_passphrase "${SSID}" "${PASS}" > root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf

ln -s \
   /usr/lib/systemd/system/wpa_supplicant@.service \
   root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service

echo Unmounting
umount root

echo Cleaning up
rmdir root
```

此后又经历了一些小事(大半天), 整个无头配置wifi连接的事就完成了.

## "我就是不想看代码"版

通篇代码都是为了防止用户搞出什么妖魔鬼怪做得防护措施, **核心代码就三条, 从`cat`命令开始, 到`ln`命令结束**, 接下来讲讲这几条代码做的事情. *闲太长的直接看后面的总结*.

在代码讲解之前先把代码的前半部分先跑一遍, 结果就是**sd卡的系统分区(非引导分区)被挂载到了工作目录下的root目录. 并且当前拥有root权限**.

### 第一句

```
cat << EOF >> root/etc/systemd/network/wlan0.network
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF
```

首先是第一句核心代码, 这一句是创建一个`systemd.network`文件并写入内容, **此文件详细用途可自行使用命令`man systemd.network`查询用法**. 概括来说就是可以创建以`.network`为后缀的任意名称的文件在`/etc/systemd/network/`, 这些文件会由进程`systemd-networkd`读取并执行, 用来配置几个网络设备.

这些文件还有两个目录可以放, 分别是`/run/systemd/network/`和`/usr/lib/systemd/network/`, 不同目录下的相同名字的文件的行为会被前一个覆盖掉, 优先级是`/etc/`大于`/run/`大于`/usr/`.

`[Match]`节是用来指定要配置的网络设备, 如果有多个文件都匹配到了同一个设备, 那么按照文件名的字符序, 先匹配到此设备的会成功配置, 其他匹配到次设备的文件会被忽略. 注意文件目录的不同不会影响到文件字符序的排名. 在这一节中, 指定要配置的网络设备名为`wlan0`

`[Network]`节指定网络设备的具体配置内容. 在这里仅启动DHCP服务.

### 第二句

```
wpa_passphrase "${SSID}" "${PASS}" > root/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

先来讲讲`wpa_passphrase`命令的功能, 超级简单, 就是把无线的名称和密码以特定的格式打印到标准输出. 通过下面的例子可以清楚看出来效果.

```
$ wpa_passphrase name_of_wireless password_of_wireless
network={
        ssid="name_of_wireless"
        #psk="password_of_wireless"
        psk=0551d34036ce41f72fcc66632e57c6b40f1313a86f92be9c28dbb6e89d597c04
}
```

然后是`/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`文件, 首先应该知道`wpa_supplicant`是一个用于管理无线网络连接的套件, 而`wpa_supplicant`程序是主程序, 其他两个辅助完成功能. 除了`wpa_supplicant`和`wpa_passphrase`以外, 还有一个程序是`wpa_cli`, 用于交互式配置无线网络连接, ~~功能丰富到不会用~~. **此套件的配置文件可以自行使用`man supplicant.conf`命令查询**.

说了这么多也没说到到底为什么是这个文件, 暂时先不提, 等把第三句看完.

### 第三句

```
ln -s \
   /usr/lib/systemd/system/wpa_supplicant@.service \
   root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
```

这一句话说废话就是创建了一个指向某个奇怪的文件的软链接放在了另一个奇怪的地方, 说玄幻一些就是手动启用了`wpa_supplicant@`服务, 先别打我, 等我说完.

ArchLinux和基于ArchLinux的发行版都使用`systemd`来管理服务, 而且越来越多的linux发行发行版开始转变到`systemd`, 简单来说就是`systemd`就是用来管理开机启动项的, 但是另一方面来说, 众多启动项彼此交错, 从挂载磁盘到配置网络, 从启动一个终端到初始化图形化界面, 相互之间顺序虽然不严格, 但是绝对不能出现冲突的顺序, 如果网络都还没配置好, 那启动了http服务也是白搭. 另一方面`systemd`还会监视进程, 一旦某个服务异常终止, 立即要尝试重新启动, 此外还要重定向一下服务进程的输出并作为日志保存.

`systemd`的配置文件主要有两个位置, `/etc/systemd/`, `/usr/lib/systemd/`, 此外还有`/run/systemd/`应该也是, 这里面可以保存服务等的配置文件, 调用时使用`systemctl start <服务名>`即可启动服务, 若想开机启动服务, 则要配置`[install]`之后才可以使用`systemctl enable <服务名>`来实现.

通过以下例子可以看出来, 如果代码过长是横拉屏幕而不是自动换行的话应该看起来很不错, 这里在每一次输入命令前都加了一个额外的空行便于观看.

```
# cat << EOF >> test-service.service
> [Service]
> ExecStart=echo "hello, world!"
> [Install]
> WantedBy=multi-user.target
> EOF

# systemctl start test-service

# systemctl status test-service
● test-service.service
   Loaded: loaded (/etc/systemd/system/test-service.service; disabled; vendor preset: disabled)
   Active: inactive (dead)

2月 06 21:23:39 manjaro systemd[1]: Started test-service.service.
2月 06 21:23:39 manjaro echo[25515]: hello, world!
2月 06 21:23:39 manjaro systemd[1]: test-service.service: Succeeded.

# systemctl enable test-service
Created symlink /etc/systemd/system/multi-user.target.wants/test-service.service → /etc/systemd/system/test-service.service.

# systemctl disable test-service
Removed /etc/systemd/system/multi-user.target.wants/test-service.service.
```

这个例子我们创建了一个最简单的服务并启动了它, 然后使用`systemctl status`查看它的状态, 显示当前未活动(`inactive`), 没有自动启动安排('disabled`), 然后下面三行是日志, 指示了启动/运行结果/结束.

然后重点来了, 我们使用`systemctl enable`和`systemctl disable`来启用自动启动和禁用自动启动, 然后`systemctl`做了什么? 它说它创建了链接! 仔细看可以发现, 软链接创建的位置就是我们写的`WantedBy`的参数指明的target, 而且链接指向原本的服务.

, 接下来我们看一看我们刚刚创建的软链接指向的服务文件的内容.

```
[Unit]
Description=WPA supplicant daemon (interface-specific version)
Requires=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device
Before=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/wpa_supplicant -c/etc/wpa_supplicant/wpa_supplicant-%I.conf -i%I

[Install]
Alias=multi-user.target.wants/wpa_supplicant@%i.service
```

但看`ExecStart`一条, 启动了一个`wpa_supplicant`程序, 使用`-c`参数制定了我们第二句写的文件.

到这里再提一下, **以`@`为文件名结尾的服务文件有特殊意义**, 即服务被调用时, `@`后填写什么与调用哪一个服务文件无关, 而是在服务文件内可以使用%I来获得从字符`@`后到`.service`后缀名之间的文本. 比如启动一个`foo@bar.service`的服务, 那么`systemd`就会启动一个`foo@.service`的服务并把`bar`作为`%I`的替换.

## 总结

所以破案了, 我们第三句创建的软链接启用了一个`systemd`服务, 并把设备名作为`%I`参数传给服务文件, 然后服务通过此参数又找到了第二句写的配置文件来链接无线网络. 此外第一句启用了网络设备的DHCP服务, 以免连接上无线却没有IP导致无法通信.

## 碎碎念

### 起因

先是想尝试折腾交叉编译, 然后发现raspbian是arm32的, 就突然觉得raspbian不好使了, 就寻思着换用archLinux或者以之为基础的发行版.

其实总体来说换个系统没什么麻烦的, 无非就是把系统映像往SD卡里面一写, 然后网线一插并开机, ssh上就万事大吉了, 最多就是在写映像时有的需要手动分一下区罢了.

然后目前的问题则是, **在连一根网线也没有的情况下, 如何才能让树莓派开机就连上wifi**. 所以查了N久资料以后看到这番代码以后, 终于配置成功并出现了这篇文章.

### 当下

最开始想使用manjaro, 下载以后苦于没有找到什么无头安装的方法, 于是下载了archlinux, 然后发现虽然archlinuxarm可以无头安装, 但是直接配置wifi又没有什么方法, 于是就回到原点. 直到找到了这段代码, 便成功安装了archlinuxarm, 然后发现好像也不是arm64, 又看到manjaro从19.10版本后支持无头安装, 并且manjaro下载就是64bit的, 于是欣然决定, 再换到manjaro, 所以现在是在用manjaro

## 参考资料

- [Installing Arch Linux on Raspberry Pi with Immediate WiFi Access](https://ladvien.com/installing-arch-linux-raspberry-pi-zero-w/)
- man page of `systemd`, `systemd.network`, `systemd.service`
- [Manjaro headless installation and wifi setup](https://www.raspberrypi.org/forums/viewtopic.php?t=250676)
