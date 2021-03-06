---
title: vsftp 配置,踩坑和一些理解
date: 2019-10-01 20:53:00 +0800
layout: post
categories: linux
tags: [ linux, vsftp ]
---

## 1. vsftpd虚拟用户的配置

配置vsftpd的虚拟用户简单分为三个方面

1. 配置pam模块                     (见下方小标题)
2. 创建认证信息文件(passwd文件)     (见下方小标题)
3. vsftpd.conf配置文件

### 1.1 PAM模块

pam (*Pluggable Authentication Modules*)为应用和服务提供动态的认证支持, pam模块一般在``/lib/security/``或``/lib/(arch_type)/security``下.

#### 1.1.1 仅虚拟用户的PAM

实现仅虚拟用户登录十分简单, 只需要让PAM仅认证虚拟用户即可, 如下指定需要的pam模块和需要的参数即可.

```conf
# 文件为 /etc/pam.d/vsftpd

auth required pam_pwdfile.so pwdfile /etc/vsftpd/.passwd
account required pam_permit.so
```

#### 1.1.2 仅本地用户的PAM

一般默认的pam文件即可实现仅本地用户认证, 保持默认即可, 不同的系统的默认pam文件内容也不同

```conf
#%PAM-1.0
# PAM of ArchLinux

auth       required /lib/security/pam_listfile.so item=user sense=deny file=/etc/ftpusers onerr=succeed
auth       required /lib/security/pam_unix.so shadow nullok
auth       required /lib/security/pam_shells.so
account    required /lib/security/pam_unix.so
session    required /lib/security/pam_unix.so

```

```conf
## Standard behaviour for ftpd(8).
# PAM of Ununtu

## Note: vsftpd handles anonymous logins on its own. Do not enable pam_ftp.so.
#
## Standard pam includes

@include common-account
@include common-session
@include common-auth
auth   required        pam_shells.so
```

#### 1.1.3 同时允许本地和虚拟用户的PAM

由于Arch Linux和Ubuntu默认的PAM文件不一样, 所以两个配置有所不同.

如果简单地允许本地和虚拟用户的PAM加在一起, 结果并不是同时允许本地用户和虚拟用户, 因为文档中描述``required``和``requisite``都会在验证失败时直接返回失败, 而``sufficient``在本次验证失败, 则会继续进行后续模块的验证, 所以我的做法是将虚拟用户的验证模块由``required``变更为``sufficient``后添加到本地用户验证模块之前.[^1]

> - required
>
>      failure of such a PAM will ultimately lead to the PAM-API returning failure   but only after the remaining stacked modules (for this service and type)   have been invoked
>
> - requisite
>
>      like required, however, in the case that such a module returns a failure,   control is directly returned to the application.
>
> - sufficient
>
>      success of such a module is enough to satisfy the authentication   requirements of the stack of modules (if a prior required module has failed   the success of this one is ignored). A failure of this module is not deemed   as fatal to satisfying the application that this type has succeeded. If the   module succeeds the PAM framework returns success to the application   immediately without trying any other modules.

注意, Arch Linux的``pam_pwdfile``模块需要在[archlinux.org](archlinux.org)中的AUR自行安装.

```conf
#%PAM-1.0
# PAM of ArchLinux

auth       sufficient /lib/security/pam_pwdfile.so pwdfile /etc/vsftpd/.passwd
account    sufficient /lib/security/pam_permit.so

auth       required /lib/security/pam_listfile.so item=user sense=deny file=/etc/ftpusers onerr=succeed
auth       required /lib/security/pam_unix.so shadow nullok
auth       required /lib/security/pam_shells.so
account    required /lib/security/pam_unix.so
session    required /lib/security/pam_unix.so
```

Ubuntu WSL 的配置直接将虚拟用户认证模块粘贴到``@include``之前不能达到期望的结果, 于是参照 Arch Linux 的配置改为如下后成功.

```conf
#%PAM-1.0
# PAM of Ubuntu

auth     sufficient pam_pwdfile.so pwdfile /etc/vsftpd/.passwd
account  sufficient pam_permit.so

auth required pam_listfile.so item=user sense=deny file=/etc/vsftpd.ftpusers onerr=succeed
auth required pam_unix.so shadow nullok
auth required pam_shells.so
account required pam_unix.so
session required pam_unix.so
```

### 1.2 虚拟用户的passwd文件

这个文件的路径和文件名都写在pam模块中, 如``sufficient /lib/security/pam_pwdfile.so pwdfile /etc/vsftpd/.passwd``的最后一个区域便是.

文件格式就是每行以用户名为起始, 冒号分隔, 后接MD5加密的密码, 样例如下:

```text
test:$1$aT64AHTK$/xRnwvHafFmTzo6GpaCZL/
```

密码加密可以使用``openssl passwd -1 -noverify ${yourPasswd}``来加密, 只需要将此命令的输出作为加密后密码追加在冒号之后即可.

### 1.3 vsftpd.conf配置文件

启用``guest_enable``选项, 该选项允许虚拟用户一个本地映射用户, 启用虚拟用户**必须配置**, 这一模式下, 所有的非匿名用户都会被映射为``guest_username``用户, **包括本地用户**, 此选项在**启用虚拟用户时是必需的**.

可选配置``guest_username``选项, 如果不配置, 默认为``ftp``, 该选项是指定映射的本地用户的用户名.

可选配置``virtual_use_local_privs`` , 该选项令虚拟用户使用本地权限, 即上一条选项相关的``guest_username``的权限, 否则虚拟用户的权限将会与匿名用户同级.

## 2. 主动模式和被动模式

首先需要先明确ftp连接有两条连接, 一个是控制信道, 用于进行认证和命令操作, 另一个是数据信道, 用于传输文件内容.

**被动模式**中, 客户端向服务器发出连接请求时, 连接的都是控制信道, 然后通过``pasv``进入被动模式, 服务端会返回一个类似``(10,16,55,114,47,70)``的一个文本, 其中前4段就是数据信道的IP地址, 后2段就是数据信道的端口信息, 然后客户端就会根据这些信息发出连接请求进行数据信道的连接.

关于被动模式下具体端口的计算方法, 简单地说就是倒数第二段乘以256加上倒数第一段, 如上就是``47 * 256 + 70``得到``12102``即为数据信道的端口. 具体一些就是因为端口号的范围时``0-65535``, 即``2^16``, 于是在发送时, 将16位二进制数拆分成两个8位二进制数, 比如上边的``12102``就是``0010 1111 0100 0110``被拆分成``0010 1111``和``0100 0110``, 于是分别以``47``和``70``发送过来.

**主动模式**则是由在连接控制信道后, 通过``port``命令向服务器发送端口信息, 由服务器向客户端发起连接请求.

整体上, 主动模式和被动模式各有优缺点, 主动模式部署较为简单, 而且由于是服务端向客户端发送连接请求, 可以很大程度上消除被其他人获取数据信道的可能, 但是缺点则是在IPv4环境下, 绝大多数的客户端都是在NAT下, 这种网络情况很难实现服务端向客户端的连接, 令每一个客户端都在生成自己监听的数据信道的端口的同时令NAT设备转发该端口也是不太现实.

与之相反, 被动模式则完全不慌客户端处在NAT设备后的情况, 但是唯一的小慌的便是服务端处在NAT下的情况, 不过解决办法也很简单, 只需要指定服务端被动模式监听端口的范围, 同时令自己的NAT设备转发这一范围的端口即可解决, 毕竟比起让全世界都铺满红地毯, 还是自己穿上拖鞋更为现实.

## 3. 用户

### 3.1 登录

除匿名用户外, 所有用户在登录时都需要一个本地用户与之对应, 本地用户对应的便是``/etc/passwd``文件中的用户, 虚拟用户需要启用``guest_enable``选项, 对应的用户是名为``guest_username``的选项的值, 如果``guest_enable``选项没有开启, 则会有``500 OPPS: cannot locate user entry``的报错.

### 3.2 权限

关于权限, 本地用户则直接使用Linux的本地权限, 匿名用户的权限则是进程vsftpd的运行权限, 一般是用户``ftp``的权限, 虚拟用户的权限在没有启用``virtual_use_local_privs``选项时权限与匿名用户相同, 启用该选项后则权限为选项``guest_username``所指的用户的权限.

需要澄明一点, 虚拟用户在vsftp的默认策略看来应该是处于与匿名用户同级的权限, 仅适用在一些安全等级较低的资料的共享中.

## 4. 关于chroot

vsftp硬性要求``chroot``的目录不可写, 原因是可写的``chroot``目录会受制于一种名为[Roaring Beast](https://www.auscert.org.au/bulletins/ESB-2012.0018/)的攻击方式.

本人对这种攻击方式的粗浅理解为, vsftp使用的API并没有告知vsftp当前工作环境是否为``chroot``之后的环境, 而且该API有一个在运行时更新配置文件的特性. 而每一个用户登陆后, 都会产生一个vsftpd子进程专用于对此用户的服务, 当子进程不知道当前是``chroot``环境时, 一旦进行运行时配置文件更新, 就会直接在当前环境中尝试导入库文件进行更新, 所以如果有用户在``chroot``后的根目录下创建类似``/lib``的文件夹, 再放入一些包含恶意代码的库文件, 那么攻击者则可以进行任何破坏.

## 5. 文件权限

### 5.1 文件上传后权限

- ``file_open_mode``, 默认值为``0666``, 表示文件上传后的最大权限.
- ``anon_umask``和``local_umask``, 表示文件上传后所应用的掩码, 前者为匿名用户使用的掩码, 后者为本地用户使用的掩码.

根据以上相关选项, 在如下的配置样例中, 匿名用户上传文件后权限为``664``, 普通用户上传文件后权限为``644``.

```conf
file_open_mode=0666
anon_umask=002
local_umask=022
```

### 5.2 文件修改属主及权限

- ``chown_uploads``, ``YES``或``NO``, 表示是否启用修改文件属主功能.
- ``chown_username``, 字符串, 值为修改文件属主的目标用户.
- ``chown_upload_mode``, 字符串, 值为表示文件权限的4位数字, 修改后文件权限会被固定设定为该选项表示的权限.

相关选项如上, 需要注意以下几点:

1. 修改属主仅对匿名用户生效.
2. 修改属主后, 文件的属组并不会改变.
3. 修改属主后, 文件的权限也会进行变更, 即变更为``chown_upload_mode``所描述的权限, 权限的变更在*上传后权限*之后, 也就是匿名用户上传文件后, 如果修改文件属主功能启用, 那么文件的最终权限会是``chown_upload_mode``描述的权限.

所以在以下样例中, 匿名用户上传的文件的权限为``0664``, 属主信息为``localuser:ftp`` (设ftpd守护进程运行时用户及属组为``ftp:ftp``), 注意``chown_upload_mode``设置同组可读写, 使得匿名用户自己上传文件后可以凭借组权限对文件进行读写.

```conf
file_open_mode=0666
anon_umask=002
local_umask=022

chown_uploads=YES
chown_username=localuser
chown_upload_mode=0664
```

## 6. 踩坑指南

### 6.1 报错 500 OOPS: cannot locate user entry[^2]

如果是虚拟用户登录时报错, 需要检查``guest_enable``选项是否为``YES``以及``guest_username``是否合法; 如果是本地用户, 则需要检查是否时用户名拼写错误.

### 6.2 报错 425 Security: Bad IP connecting[^4]

这一点是因为检测到控制信道和数据信道的IP不相同, 因而报出的错误, 通常出现在布置处在NAT后端的ftp服务时, 特点是使用内网/外网IP可以正常访问, 但是换用外网/内网IP就会报错而获取目录失败.

应该是为了杜绝通过某种方法获取原用户控制信道对应的数据信道, 实现获取用户下载内容的目的.

解决办法可以加一行``pasv_promiscuous=YES``解决, 这个选项是允许控制信道和数据信道IP不同, 通常用在部署一些安全信道协议中, 但是会带来一些安全隐患.

但是既然已经知道了问题出现的原因, 那么只要通过``pasv_address``选项指定特定的控制信道的IP, 并且一直通过这一IP进行访问即可, 不过使用这一选项有时会出现下面的情况, 需要注意``pasv_address``与vsftpd监听的IP类型.

### 6.3 vsftp进入被动模式时, 发送**0.0.0.0**作为数据信道的主机地址[^3]

这一点是因为vsftp的默认监听有时候是``listen_ipv6``, 这一监听模式下, ``pasv_address``配置的IPv4地址会被忽略, 于是乎发送出``0.0.0.0``给客户端进行连接.

**有一个解决办法是禁用``listen_ipv6``转而启用``listen``**.

有点绕开难点的意思, 不过在IPv6未广泛应用的情况下, 倒也勉强接受.

### 6.4 报错: 500 OOPS: vsftpd: refusing to run with writable root inside chroot()

**请修改``chroot``的目录为不可写权限!**

[^1]: https://www.linuxquestions.org/questions/linux-software-2/how-to-enable-both-virtual-and-local-vsftpd-logins-with-pam-365860/
[^2]: https://ubuntuforums.org/showthread.php?t=1679782
[^3]: https://www.centos.org/forums/viewtopic.php?t=52408
[^4]: https://www.linuxquestions.org/questions/linux-newbie-8/vsftpd-problem-with-425-security-bad-ip-connecting-120158/
