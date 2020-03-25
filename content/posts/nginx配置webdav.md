---
title: "Nginx配置webdav"
date: 2020-03-24T23:26:53+08:00
tags: [ linux, nginx ]
draft: false
---

> 本质上, webdav就是从http拓展了几条指令, 从而可以用来管理文件系统或进行文件分享.

## 目录

1. 重新编译nginx
2. webdav配置
3. 认证权限
4. SSL权限

## 重新编译nginx

原本nginx配置webdav很简单, 只要在配置文件中加入关于[这个模块](http://nginx.org/en/docs/http/ngx_http_dav_module.html)的配置就好了, 可惜官方文档中轻描淡写说了下面一句话, 然后webdav的`PROPFIND,OPTIONS,LOCK,UNLOCK`几条命令就不被支持了, 于是就需要给nginx加入新的module.

>      WebDAV clients that require additional WebDAV methods to operate will not work with this module. 

其实说是要重新编译nginx, 还是因为nginx高性能的定位, 使其不允许动态加载插件, 所以需要拿到插件源码, 配合nginx源码重新编译来达到增加插件的目的.

### 准备

先去克隆这个[arut/nginx-dav-ext-module](https://github.com/arut/nginx-dav-ext-module)这个仓库, 此仓库就是为nginx提供原module所缺失的wendav请求支持.

然后去[nginx官网](http://nginx.org/en/download.html)下载nginx的源码. 两个源码都放在一个比较方便操作的位置就好, 以下都假设放到了家目录下.

#### 编译

在编译之前, 首先需要了解nginx有一个参数是`-V`, 这个参数可以打印nginx的一些编译信息, 包括在configure步骤的参数, 如果已经现有一个可用的nginx, 只是希望替换原来的二进制程序, 保证编译后的程序和自身发行版的nginx行为尽可能相同, 则可以把此参数打印的configre参数全部复制一下.

进入nginx源码目录, 运行目录下的`configure`, 附上刚刚拿到的参数, 最后再加上一个`--add-module`的参数, 指向'arut/nginx-dav-ext-module'仓库的目录, 如下:

```
./configure <parameters copied befored> --add-module=../nginx-dav-ext-module/
```

如果在配置过程中, 提示缺少某些依赖, 通过自己的包安装器安装即可, 也可以在参数中去掉产生错误的不必要的module.

此时目录下应该出现`Makefile`文件, 这时使用`make`命令即可开始编译

```
make
```

经过取决于机器性能的编译时间以后, `objs`目录下应该已经有各种编译结果了, 可以直接在源码目录以root身份执行`make install`安装, 也可以直接将`objs`目录下的二进制可执行文件覆盖掉原来的`nginx`可执行文件.

## webdav配置

nginx的配置文件中, 每一个配置项都有自己的上下文结构, 比如`location`要在`server`或`location`里面, 在官方文档中, 如果`context`有逗号分隔, 即表示此配置可以写在多种上下文结构中. 如果某配置项直接下载文件的最外层, 那么称此配置项处于`main`上下文中.

简单来说, 只要在从最外层到内层, 依次配置好`http`,`server`,`location`即可. 换句话说, 只要在http server中加上`dav_ext_lock_zone`, `dav_ext_lock`, `dav_access`, `dav_methods`, `dav_ext_methods`五项配置即可. 

- `dav_methods` 启用的webdav方法
- `dav_ext_methods` 额外的不被原本webdav模块支持的方法
- `dav_access` 新创建文件的访问权限
- `dav_ext_lock_zone` 定义一个共享的锁空间
- `dav_ext_lock` 启用锁, 并依赖于定义的锁空间

```
http {
    include       mime.types;
    default_type  application/octet-stream;

    gzip  on;
    sendfile        on;
    
    dav_ext_lock_zone zone=webdav_lock_zone:4m;
    server {
        listen      80;
        server_name localhost;

        dav_access      user:rw group:r all:r;
        dav_methods     PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS;
        dav_ext_lock    zone=webdav_lock_zone;

        location / {
            root    /srv/webdav/;

            create_full_put_path    on;
            client_body_temp_path   /srv/webdav/temp_upload;
        }
    }
}
```

## 认证权限

身份认证基于nginx的官方模块`ngx_http_auth_basic_module`, 有`auth_basic`和`auth_basic_user_file`两个选项, 并且通用于`http`, `server`, `location`下.

- `auth_basic` 是给客户端的请求认证的提示的字符串
- `auth_basic_user_file` 则是指定依赖的认证文件

认证文件可以由Apache httpd的`htpasswd`命令生成, 也可是以如下格式

```
user1:password1:comment1
user2:password2:comment2
```

## SSL加密

此功能依赖于官方`ngx_http_ssl_module`模块. 不求甚解可以直接把默认配置里面对https服务器的SSL部分拿过来, 同时确保`ssl_certificate`和`ssl_certificate_key`两个选项指向合法的对应文件即可. 此外要求监听端口附加`ssl`声明, 如`listen 443 ssl`, 此外同一个`server`可以同时监听SSL和无加密端口.

证书和密钥可以自己生成一个不被其他人认可的, 也可以从域名服务商处或其他CA获取被认可的.

## 样例

```
http {
    include       mime.types;
    default_type  application/octet-stream;

    gzip  on;
    sendfile        on;
    
    dav_ext_lock_zone zone=webdav_lock_zone:4m;
    server {
        listen      80;
        listen      443 default_server ssl;
        server_name localhost;

        access_log /var/log/nginx/webdav/access.log;

        ssl_certificate      /etc/ssl/certs/certificate.pem;
        ssl_certificate_key  /etc/ssl/private/certificate.key;
        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;

        dav_access      user:rw group:r all:r;
        dav_methods     PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS;
        dav_ext_lock    zone=webdav_lock_zone;

        location / {
            root    /srv/webdav/;

            # enable creating directories without trailing slash
            if (-d $request_filename) { rewrite ^(.*[^/])$ $1/ break; }
            if ($request_method = MKCOL) { rewrite ^(.*[^/])$ $1/ break; }

            auth_basic              "Auth of webdav";
            auth_basic_user_file    /srv/webdav/.htpasswd;

            create_full_put_path    on;
            client_body_temp_path   /srv/webdav/temp_upload;
        }
    }
}
```
