---
title: "部署davical到apache2"
date: 2021-01-02T12:21:45+08:00
tags: [ linux, apache, caldav ]
draft: false
---

起源于 radicale 的 well-known 自动配置不能与 thunderbird 的 tbsync 插件和平地工作, 以及使用 python 实现的 radicale 在过去的半年中失去响应了 3 次, 所以决定找一个可能更稳定一些, 更加通用一些的支持 caldav 的服务程序, 最终选定了 davical .

这里将在 debian 系统 apache2 上部署 davical , 同时会配置好 well-known 的重定向, 此外还会有一些实现方式的小推测.

关于软件依赖等事项不再赘述, 这里只讨论使用 apache 部署 davical 站点的过程.

## 目录

- [目录](#目录)
- [部署 davical 站点](#部署-davical-站点)
  - [使用 VirtualHost 部署 davical 为一个新的站点](#使用-virtualhost-部署-davical-为一个新的站点)
  - [使用软链接方式部署 davical 到一个 http 子目录](#使用软链接方式部署-davical-到一个-http-子目录)
  - [使用别名(Alias)方式部署 davical 到一个 http 子目录](#使用别名alias方式部署-davical-到一个-http-子目录)
- [well-known 的配置](#well-known-的配置)
  - [使用 Rewrite 部署 well-known](#使用-rewrite-部署-well-known)
    - [客户端的访问体验](#客户端的访问体验)
  - [使用 Redirect 部署 well-known](#使用-redirect-部署-well-known)
    - [客户端的访问体验](#客户端的访问体验-1)
- [关于 Rewrite 的一些解释](#关于-rewrite-的一些解释)
- [关于 Redirect 时有无后缀斜杠的区别](#关于-redirect-时有无后缀斜杠的区别)
  - [一个关于 URI 后缀斜杠并在重定向时被替换的例子](#一个关于-uri-后缀斜杠并在重定向时被替换的例子)
  - [一个重定向与直接获取网页文档同时工作的例子](#一个重定向与直接获取网页文档同时工作的例子)

## 部署 davical 站点

部署 davical 有两大类别, 分别是部署为一个新的站点和部署为一个网站的子目录.

部署为新的站点比较方便, 而且不会对未来可能的新目录产生冲突, 但建议配合 DNS 来使用, 以免浪费一个 80 端口, 此外客户端的配置也十分简单.

部署为一个 http 子目录兼容性则会更好一些, 适用于更多场景.

### 使用 VirtualHost 部署 davical 为一个新的站点

部署为一个新的站点只需要创建一个新的 VirtualHost 条目, 并指定网页根目录 DocumentRoot 即可. 比如将新站点监听在本机所有 IP 的 81 端口, 只需要在 VirualHost 条目中通配指定所有 IP , 再指定端口 81 即可.

需要注意的是那个比较容易被忽略的 `Listen 81` 的指令, 这个指令要求 apache2 在运行时监听 81 端口, 如果没有这条指令则会发现站点无法正常使用, 表现为无法建立连接, 在服务器主机上也会发现没有任何进程监听 81 端口.

```
Listen 81
<VirtualHost *:81>
    DocumentRoot /usr/share/davical/htdocs
</VirtualHost>
```

使用这种方式配置以后, 在客户端的配置中需要指定 caldav/carddav 的目录为根目录或忽略不写路径即可.

### 使用软链接方式部署 davical 到一个 http 子目录

这种配置方式不需要去为了建立站点或重定向来修改配置文件, 只需要在当前的站点的 DocumentRoot 的文件目录中建立一个指向 davical 的 `htdocs` 的目录的软链接即可.

```
# ls -l
total 2
-rw-r--r-- 1 root root 10701 Dec 27 23:39 index.html
lrwxrwxrwx 1 root root    26 Dec 28 02:25 davical-link -> /usr/share/davical/htdocs/
```

### 使用别名(Alias)方式部署 davical 到一个 http 子目录

在需要部署的站点 (VirtualHost) 中添加 `Alias` 指令就可以实现和建立软链接相同的效果.

需要注意是否在第一个参数 URI 中后缀一个斜杠, `Alias` 对于 URI 后缀斜杠的行为与 `Redirect` 类似, 具体在[关于 Redirect 时有无后缀斜杠的区别](#关于-redirect-时有无后缀斜杠的区别)中描述.

```
Alias "/davical" "/usr/share/davical/htdocs/"
```

## well-known 的配置

well-known 是一个将各种可能在网页文档某个路径的服务另外在路径 `/.well-known/` 下为指定名称的文档请求返回跳转响应的约定.

> 比如 caldav 服务部署在 `/davical/caldav.php` 路径, 若配置好 well-known 则访问 `/.well-known/caldav` URI 时, 会在得到一个响应头, 其中 `location` 字段为 `/davical/caldav.php`, 状态码为任意一个跳转状态码 (如 301 或 302), 随后客户端会根据得到的 URI 去再一次请求服务.

对于 davical 的 well-known 的配置可以参见其 [wiki (Well-known URLs)](https://wiki.davical.org/index.php/Well-known_URLs) , 下面也会进行简短的复述.

davical 的 well-known 工作机制要求 well-known 的访问被 `/davical-base/caldav.php/.well-known/caldav` 处理, 处理结果中, GET 请求会直接在此 URI 的网页文档下处理, **而 caldav 中用到的 PROPFIND 等请求会返回一个重定向响应, 响应路径为 `/davical-base/caldav.php`** .

在 apache 的配置当中, **一切配置的目的都是将访问到 `/.well-known/caldav` 到请求重定向到 `/davical-base/caldav.php/.well-known/caldav`**, 实现这一目的的手段有对用户透明的 `Rewrite` 和用户可见的 `Redirect` 两种.

### 使用 Rewrite 部署 well-known

假设 davical 被部署在 `/davical-base/` 下, 使用 `Rewrite` 需要先引入模块 `mod_rewrite`, 仅重写 caldav 服务的情况时, 配置如下.

```
RewriteEngine On
RewriteRule ^/\.well-known/caldav$ /davical-base/caldav.php/.well-known/caldav [NC,L]
```

#### 客户端的访问体验

```
Request: PROPFIND http://hostname/.well-known/caldav
Response: 301 location=/davical-base/caldav.php

Request: PROPFIND http://hostname/davical-base/caldav.php
Response: ... ... ... ...
```

### 使用 Redirect 部署 well-known

假设 davical 被部署在同一位置, 仅重写 caldav 服务时, 配置如下.

```
Redirect /.well-known/caldav /davical-base/caldav.php/.well-known/caldav
```

#### 客户端的访问体验

```
Request: PROPFIND http://hostname/.well-known/caldav
Response: 302 location=/davical-base/caldav.php/.well-known/caldav

Request: PROPFIND http://hostname/davical-base/caldav.php/.well-known/caldav
Response: 301 location=/davical-base/caldav.php

Request: PROPFIND http://hostname/davical-base/caldav.php
Response: ... ... ... ...
```

## 关于 Rewrite 的一些解释

`Rewrite` 是简单的修改 URI , 然后将修改后的 URI 中的资源作为响应返回给请求, **这一过程对于客户端是透明的**.

## 关于 Redirect 时有无后缀斜杠的区别

Redirect 只是一个普通的查找替换, 相当于将 URI 中特定前缀替换为第二个参数表述的字符串以后, 将修改之后的 URI 作为响应头中的 location 字段值并以 301 作为状态码返回给浏览器.

此外, 对于目录文件, 如果 URI 的目标刚好是一个目录文件, 在匹配唯一的情况下, 是否后缀斜杠以及后缀多少个斜杠对于目录项来说没有区别, 即 `/dir` 与 `/dir/` `/dir//` 没有区别. 而对于普通文档, 则后缀一个额外的斜杠以后会无法访问该文档.

### 一个关于 URI 后缀斜杠并在重定向时被替换的例子

所以对于是否加上斜杠, 应考虑是否需要要以斜杠的方式访问. 如网页根目录内容以及目标为 `tmp-file` 的重定向如下.

```
# content of the DocumentRoot
-rw-r--r-- 1 root root   9 Jan  2 00:09 tmp-file

# directive in VirtualHost
Redirect /redirect-file/ /tmp-file
```

浏览器访问 URI 为 `http://hostname/redirect-file/` 的网页时, 得到的响应头如下.

```
HTTP/1.1 302 Found
Date: Sat, 02 Jan 2021 06:43:49 GMT
Server: Apache/2.4.38 (Debian)
Location: http://hostname/tmp-file
Content-Length: 296
Keep-Alive: timeout=5, max=100
Connection: Keep-Alive
Content-Type: text/html; charset=iso-8859-1
```

随后浏览器跳转到 `http://hostname/tmp-file` 最终获取到真正的网页.

请留意 302 跳转时浏览器访问时提供的 URI 中后缀的斜杠, 以及重定向指令中的源 URI 中的斜杠.

当访问的 URI 中没有后缀斜杠时, 即访问时提供的 URI 为 `http://hostname/redirect-file` 时, 此重定向指令将不会生效, 最终浏览器得到一个 404 的响应.

### 一个重定向与直接获取网页文档同时工作的例子

```
# content of the DocumentRoot
-rw-r--r-- 1 root root   9 Jan  2 00:09 redirect-dir
drw-r--r-- 1 root root   9 Jan  2 00:09 tmp-dir

# directive in VirtualHost
Redirect /redirect-dir/ /tmp-dir
```

当如上配置时, URI 为 `http://hostname/redirect-dir` 时, 会直接获取到文件 `redirect-dir` 的内容, 当 URI 为 `http://hostname/redirect-dir/` 时, 会访问到**目录** `tmp-dir` 的内容.
