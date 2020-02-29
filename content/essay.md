---
title: "Essay"
type: section
date: 2020-02-14
draft: false
---

用来随便记一些什么, 也可以认为是博文前的草稿, 不定时上传.

---

## snap 代理设置

`set`命令用来设置变量值, `get`命令则可以获取变量值. 推测配置格式类似json.

```
# 以下两句可以获取包"system"的配置选项和其下的"proxy"的配置选项
snap get system
snap get system proxy
```

```
snap set system proxy.http="http://<host>:<port>"
snap set system proxy.https="http://<host>:<port>"
```

---

## C++继承 从子类调取父类静态函数是否会误调用成员函数

在子类调用父类函数时, 使用``parent::function``形式来显式调用父类函数, 避免调用自身的重写的函数.

**静态函数和成员函数同名有冲突**, 所以在继承中, 子类调用父类的函数时, 使用的``parent::function``形式不会出现无法调用父类静态函数的问题.

只有使用公有继承, 子类才能作为参数为父类的函数的参数.

---

## ASNI编码和UNICODE编码

ASNI编码即0x80到0xFFFF范围的编码, 即拓展ASCII编码. 在不同的国家和地区中, 制定了不同的编码标准, 如简中的GBK等, 相同点则是使用1字节表示英文字符, 使用2字节表示当地字符. 这些使用多个字节表示一个字符的延伸编码方式, 称之为ASNI编码.

为了解决字符编码需要相互转换以及不同语言文字并排的问题, 众多公司联合起来制定了UNICODE编码, 此编码囊括全球所有的语言文字.

UTF全称(Unicode Transformation Format), 即Unicode转换格式, 是Unicode的实现方式, UTF-8是一种变长编码, 使用7位与ASCII编码对应, 遇到其他UNICODE编码则按照一定的算法转换, 得到UNICODE原编码.

---

## JavaScript中的var和let

> 摘录总结自MDN

### let

- 作用域为当前块
- 会在编译时才被初始化
- 在上一个let声明的变量的作用域中重复声明该变量, 会报出语法错误

### var

- 作用域为当前执行上下文
- 不论声明位置, 都在代码执行前处理
- 重新声明一个变量不会丢失其值.

### 区分性代码

#### let 与 var 的作用域

```js
function varTest() {
  var x = 1;
  {
    var x = 2;  // 同样的变量!
    console.log(x);  // 2
  }
  console.log(x);  // 2
}

function letTest() {
  let x = 1;
  {
    let x = 2;  // 不同的变量
    console.log(x);  // 2
  }
  console.log(x);  // 1
}
```

#### var 与 不加声明的变量

```js
function x() {
  y = 1;   // 在严格模式（strict mode）下会抛出 ReferenceError 异常
  var z = 2;
}

x();

console.log(y); // 打印 "1"
console.log(z); // 抛出 ReferenceError: z 未在 x 外部声明
```

---

## 浏览器cookie小理解

在控制台中敲入`document.cookie`可以获取当前有效的cookie, 这些内容是经过处理的, 不包含过期时间/主机等参数的cookie字符串.

需要理解什么是一个cookie条目, 即一个键值对就是一个条目. 对`document.cookie`这一"虚假的字符串"进行处理的时候, 每次操作只能处理一个条目. 可以理解为cookie是一个数据库, 而向数据库发送指令的方法就是对`document.cookie`赋值, 只不过指令只有对特定列赋值的形式.

设定cookie只需要对`document.cookie`赋值. 赋值语句有特定的格式, 要求使用的字符串必须为`"<name>=<value>"`的格式(如果省略name和/或等于号, 那么创建的cookie将是名字为长度为0的字符串的条目, 仍然可以正常使用), 并且默认为会话期cookie, 会话期cookie在关闭浏览器后会自动清除. 设定条目的过期时间以后则cookie根据时间条件来清除cookie, 赋值格式为`"<name>=<value>; Expires=<GMT TIME>"`, 注意要保存的键值对一定要位于最开始.

删除一条cookie, 需要重新对这一名称的cookie条目重新赋值, 并且此条目的过期时间早于当前时间.

```js
// 创建会话期cookie
document.cookie = "test_cookie=123;"

// 创建定时过期的cookie
document.cookie = "test_cookie=123; Expires=Tue Feb 25 2020 23:59:59 GMT+0800";

// 删除某条目cookie
document.cookie = "test_cookie=; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
```

---

## C++数据模型与整数类型的位宽

> 此篇总结自[基础类型 - cppreference.com](https://zh.cppreference.com/w/cpp/language/types)

每个实现关于基础类型大小所做的选择被统称为**数据模型**, 有4个广为接受: `LP32(2/2/4), ILP32(4/4/4), LLP64(4/4/8), LP64(4/8/8)`

数据模型中`I`表示`int`, `L`表示`long`, `LL`表示`long long`, `P`表示指针, `32`和`64`表示系统位数. 以上`ILP32`就表示`int`,`long`以及以上还有指针均有32位宽. `LP64`表示`long`以及以上还有指针均有64位宽.

目前Win32和Unix32位采用`ILP32`, Win64采用`LLP64`, Unix64位采用`LP64`.

总结可知, 常见系统上基础类型数据位宽实现相同的有`short - 16bit`, `int - 32bit`, `long long - 64bit`. 此外只有Unix使用64bit`long`, 其他为32bit的`long`

对于字符类型, `char`固定占1字节, `wchar_t`占32位4字节, 例外的是Windows中的`wchar_t`占16位并保有UTF-16编码单元.

---

## 交叉编译

> 参考自[How to Build a GCC Cross-Compiler](https://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/)

### 构造步骤提要

1. 使用本机的gcc编译跨平台的构建`binutils`, 这一步是为了构建汇编器和链接器等. (binutils内)
2. 安装目标linux的头文件, 注意指定目标的指令集, 这一步与上一步无必须的先后关系 (linux内)
3. 使用本机gcc编译安装交叉编译器. (boostrap gcc内)
4. 编译标准C库启动文件及安装C库头文件, 依赖上一步的交叉编译器 (glibc内)
5. 安装编译器支持库, 此步依赖于上一步的C库 (gcc内)
6. 安装标准C库, 依赖上一步的编译器支持库和第二步的头文件 (glibc内)
7. 安装标准C++库, 依赖上一步的标准C库 (gcc内)

---

## todo

- [x] CommonClipboard - use cookie to save server last connected.
- [ ] OpenSSL generate certifiate
- [x] todo panel on KDE