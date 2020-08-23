---
title: "Webdav的挂载"
date: 2020-08-23T11:28:36+08:00
tags: [ linux, mount, systemd ]
draft: false
---

webdav 挂载到本地文件系统有优有劣, 好处是权限更加开放, 使用也比较方便, 但缺点是在需要同步时受网络影响较大, 所以建议不要直接打开挂载到本地目录的 webdav 文件, 尤其是 GUI 会卡顿较长时间.

> 使用 webdav 的本意是同步一下 keepass 密码格式的数据库, 摆脱所有密码都一样的困扰, 于是采取了 webdav 挂载到PC本地目录, 安卓使用 FolderSync 进行同步的解决方案, 实际体验不太令人满意, PC打开文件都需要等待少则几秒的下载文件的时间, 而安卓端由于 webdav 本就不是用来同步的协议, 同步过程中也会出现很多的冲突问题.
> 
> 新的解决方案是使用 syncthing 进行 keepass 数据库文件的同步, 有点是每一个终端都会有一个数据库文件的备份, 即便突然断网, 也会有本地备份来供短期使用, 而且本地备份文件在被打开时不需要等待漫长的下载时间.

由于种种原因要弃用 webdav, 但在弃用前将自动挂载 webdav 的配置做一下笔记.

## 准备条件

安装挂载 webdav 的驱动 `davfs2`, 安装以后可以使用 `mount` 指定 `davfs` 的文件系统格式从而从命令行进行挂载.

准备一个 webdav 的文件服务, 本人由于当初对于 webdav 的强烈需求以及对容量的极小需求采用了[Koofr](!https://koofr.eu/), (初始空间2G, 支持 webdav, 大陆可用, 速度一般), webdav 的配置信息可以在[这里](!https://koofr.eu/help/koofr_with_webdav/how-do-i-connect-a-service-to-koofr-through-webdav/)找到.

## 配置记住密码

安装好 `davfs2` 以后, 可以在 `~/.davfs2/secrets` 文件中配置挂载目录的远程地址\用户名\密码, 配置样例如下

```
https://app.koofr.net/dav/Koofr leafee98@hotmail.com ThisIsMyPasswordAndIWillNotLetYouKnow2333~
```

## 配置自动给本用户挂载

配置本用户自动挂载而不是自动挂载给所有用户, 需要实现不使用 `sudo` 来挂载目录, 这一点只需要在 `/etc/fstab` 文件中写出相应的挂载选项并给出 `user` 选项就可以.

在 `fstab` 的配置中, 配置分为4列, 分别是 `设备标识/远程地址`, `挂载位置`, `文件系统格式`, `其他选项`, 其中其他选项可以查看对应文件系统的手册了解, 比如上面提到的 `user` 选项就在 `mount.davfs(8)` 中可以找到, 其效果是 `allow  an  ordinary  user  to mount the file system`, 此外 `noauto` 的效果是在不能使用 `mount -a` 进行自动挂载, 也即开机时不会自动挂载. 本次配置结果如下.

```
# webdav
https://app.koofr.net/dav/Koofr /home/leafee98/Koofr/ davfs user,noauto,uid=2333,gid=2333,file_mode=0664,dir_mode=2775,grpid,rw,_netdev 0 0
```

上述中配置了开机时不会自动挂载, 那么如何使本用户可以在登录时挂载此目录呢, 这里使用了 `systemd` 的 `mount` 类型的服务, 配置内容和 `fstabs` 差不多, 但是需要**注意 `mount` 类型的服务名称和挂载位置相对应**, **`Option` 的内容也需要和 `/etc/fstab` 的内容相一致**, 如下

```
# file name: home-leafee98-Koofr.mount
# file path: /home/leafee98/.config/systemd/user/
[Unit]
Description=Mount WebDAV Service
After=network-online.target
Wants=network-online.target

[Mount]
What=https://app.koofr.net/dav/Koofr
Where=/home/leafee98/Koofr/
Options=user,uid=2333,gid=2333,file_mode=0664,dir_mode=2775,grpid,rw,_netdev
Type=davfs
TimeoutSec=15

[Install]
WantedBy=default.target
```

接下来只需要启用这个服务就可以实现开机自动为本用户挂载了.

```
systemctl --user enable home-leafee98-Koofr.mount
```

## 其他一些不小不大的问题

由于这个服务是在本用户(`~/.config/systemd/user/`)的目录下, 所以在启用服务时只有此用户可以看到.

只不过, 由于挂载信息还保存在 `/etc/fstab/` 下, 所以其他用户使用命令行也会启用这个服务就是了.

此外, 如果在 `/etc/fstab` 里面将 `noauto` 选项去掉, 那么这一个额外的服务就可以省略掉. ~~所以这额外的服务折腾了半天就是自己折腾自己~~
