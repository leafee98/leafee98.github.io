---
title: Linux服务 -- systemd.unit
date: 2019-09-14 04:09:45 +0800
layout: post
categories: linux
tags: [ linux, systemctl ]

---


## 概括

通过``systemctl``命令可以对服务进行一些基本操作, 包括启动,停止,重启等, 而这条命令操作的服务的位置就在``/etc/systemd/system``目录下, 如果想要我们想要创建一个自己的服务用于开机自动运行, 只需要在这个目录下创建一个名为``{your service name}.service``的文本文件即可, 最简单的服务只需要在文件内写出``[Service]``部分中的``ExecStart``即可运行服务.

## Linux服务

Linux服务一般通过``systemctl``进行管理, 诸如``systemctl start {service name}``启动某服务, 优点就是十分统一, 并且使得各种各样的服务有条理地运行, 不至于发生一个服务明明需要另一个服务的功能, 却在另一个服务运行之前启动, 造成启动失败或者异常.

``systemctl status {service name}``可以查看服务的状态, 同时会显示出服务最近的几行日志, 如果需要查看更多的日志, 可以使用``journalctl -u {service name}``, 其中``-u``参数是指定unit

## service文件

常用的部分有三个:``Unit``, ``Service``, ``Install``

#### Unit

``Unit``部分是``systemctl``管理的众多模块的通用配置的部分, 这一部分可以写``Description``, ``After``等. ``Description``就是描述, 在``status``作为参数的时候可以在状态的部分看到这里写的描述; ``After``就是指定服务启动的顺序, ``systemd``会读取所有模块(Unit), 根据``Before``,``After``,``Require``等参数构造出一个不会对任何模块造成冲突的启动顺序, 然后依次启动服务, 对于``Require``等参数在前置服务启动失败时还可以指定特殊的行为

#### Service

这一部分就是服务的主体部分, 最最最重要的就是``ExecStart``参数, 即启动服务时运行的命令, 其他的诸如``ExecStop``,``ExecReload``等就是停止和启动服务时运行的命令.

另一个比较重要的参数就是``User``, 这个参数表示以特定用户的身份启动服务.

#### Install

这一部分是在服务需要开机启动时必须的项, 使用``systemctl enable {service name}`` 可以使服务在开机时启动, 其实也就是在特定目录下创建一个指向服务文件的软链接

## 示例

```
[Unit]
Description=syncthing service for leafee98
After=network.target

[Service]
User=leafee98
ExecStart=/usr/bin/syncthing -no-browser -gui-address=0.0.0.0:8384 -home=/mnt/leafee98/syncthing/syncHome/

[Install]
WantedBy=multi-user.target
```

