---
title: Linux计划任务 -- crontab
layout: post
tags: [ linux, crontab ]
categories: [linux]
date: 2019-09-17 11:04:15 +0800
---


## 使用语法

crontab 的每行命令有5个日期时间部分，5个部分之间使用space或tab分隔，后面接着需要执行的命令

#### 时间日期部分

这一部分语法如下，但是如果不准备深入了解，可以在[crontab guru](crontab.guru)来简单地配置需要的时间

```shell
mm hh DD MM dd {command}
# mm : minute (0-59)
# hh : hour (0-23)
# DD : day of month (1-31)
# MM : month (1-12)(or use name)
# dd : day of week (0-7)(0 or 7 is sunday)(or use name)
```

- 每一个日期时间的部分都可以使用范围表示``0 0 1 1 1-4``即``0分 0时 1日 1月 周1至周4``
- 使用星号表示该区域的值可以为任意值``0 0 1 * *``即``0分 0时 1日 任意月 一周内任意天``
- 使用逗号可以并列多个允许时间``0 0 * * 1,5``表示``0分 0时 0 任意日 任意月 周一和周五``
- 使用斜杠可以设定步长``* */2 * * *``表示``每两个小时``，``1-7/2``表示``1,3,5,7``
- 月和周可以使用英文名称，但是列表（逗号分隔）和范围（短横线）将会不再可用


#### 时间的另一种表示

除使用5段字符来描述运行的时间外，还可以使用内置的8个字符串来代替这5段字符，这8个字符串中只有`@reboot`是无法用5段字符描述，并且它指示的时间是守护进程`cron`启动的时间，所以具体的启动时机与系统的启动顺序有关

```shell
@reboot -- run once, at startup
@yearly -- run once a year '0 0 1 1 *'
@annually -- (same as @yearly)
@monthly -- run once a month '0 0 1 * *'
@weekly -- run once a week '0 0 * * 0'
@daily -- run once a day '0 0 * * *'
@midnight -- (same as @daily)
@hourly -- run once an hour '0 * * * *'
```

#### 命令部分

- 百分号后的字符会以标准输入的方式输入给命令，除非使用反斜杠escape
- 结尾使用反斜杠**不可以**将命令另起一行而不打断命令


## 注意事项

#### 环境变量

设定环境变量只需要使用`key = value`即可，每一条环境变量的赋值命令都需要另起一行，等号两边的空格是可选的，其中的`value`可选被引号包括，单双引号均可但必须匹配，设定空值时必须使用引号

这些环境变量可以在命令部分使用，但是环境变量时，使用美元符号引用之前的变量的用法将失效，如以下的命令将不再以期望的方式运行

```shell
a = 1
b = 2
c = $a $b
```
crontab的环境变量与普通shell环境有所不同，它采用的shell是`/bin/sh`, 并且`path=/usr/bin:/bin`，修改默认shell和mailto的示例如下

```
SHELL = /bin/bash
MAILTO = paul
```

#### 时区

cron的时间与当前时区有关，然而由于时区不能由各用户自定义，所以整个系统的cron只能按照统一的一个时区来工作
