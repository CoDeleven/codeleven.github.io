---
title: 《深入剖析Tomcat》之第一章
date: 2018-06-18 16:06:17
tags: Tomcat
---

本章主要学习了如何自己搭建简易的Socket服务器/客户端。内容从以下几个部分展开：
* HTTP请求结构
* Socket/ServerSocket
* 结构剖析


# HTTP请求结构
HTTP允许WEB服务器和浏览器通过Internet发送并接收数据，是一种基于“请求-响应”的 **协议**。客户端请求一个文件，HTTP服务器会对该请求进行响应。HTTP使用可靠的TCP链接，默认端口为80.

在搭建自己的简易服务器之前，我们需要了解一下[HTTP的规范](https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5)。

在这里简单的介绍一下：
```
// Method是指请求方法、space是空格、Request-Uri是请求的Uri、Http-Version是指Http版本、CRLF是\r\n
Method space Request-Uri space Http-Version CRLF
// 代表通用的header，比如Cache-Control、Connection、Date等可以在请求、响应里使用的
[general-header]{0,} CRLF
// 请求专用的头部
[request-header]{0,} CRLF
// 实体头部，通常是带有实体时才会存在该部分
[entity-header] CRLF
CRLF
[message-body]
```
响应请求也是差不多的结构，就是request-header 改成 response-header

# Socket/ServerSocket
这两个API统称为 **套接字**，套接字能让应用程序从网络中读取数据，也可以向网络中写入数据。

## Socket
客户端需要使用Socket连接服务器，以下是其众多构造函数之一，第一个参数是主机名（或IP地址），参数port是连接远程应用程序的端口。
`public Socket(java.lang.String host, int port)`

比如要连接 **bilibili.com**，可以使用下面的语句创建Socket：
`new Socket("bilibili.com", 80);`

一旦成功创建了Socket类的实例，就可以使用该实例发送或接收字节流。要发送字节流，需要调用Socket类的getOutputStream()获取输出流，如果要接收另一端的数据，则需要调用getInputStream()获取输入流。

## ServerSocket
服务端需要使用ServerSocket监听机器上的某个端口是否有请求到达，ServerSocket提供了4种构造函数，我们使用其中任意一个即可：
`public ServerSocket(int port, int backLog, InetAddress bindingAddress)`
第一个参数表示要监听的端口，第二个参数表示最大可接受的连接请求队列，第三个为想要绑定的IP地址（适用于多网卡的主机）

更加具体的可以看[Socket和ServerSocket详解]();

# 结构剖析
该Web应用主要包括3个类：
* Server
* Request
* Response

该章学习到的结构方面的内容如下所示：
```java
        // 获取InputStream封装到Request里
        Request request = new Request(conn.getInputStream());
        // 对接收到的内容进行解析
        request.parse();
        // 获取OutputStream封装到Response里
        Response response = new Response(conn.getOutputStream());
        // 将Request设置给Response，Response需要知道Request的内容
        response.setRequest(request);
        // 发送响应
        response.sendStaticResource();
```
该结构其实就是Tomcat以宏观角度看到的情形，将接收的请求数据封装到Request，将输出流封装到Response里，然后将Request和Response均交给service()方法处理。

# 代码
[代码](https://github.com/CoDeleven/Immerse2Tomcat/tree/master/ch01-SimpleHttp)
