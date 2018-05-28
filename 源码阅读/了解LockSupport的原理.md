---
title: 了解LockSupport的原理
date: 2018-04-05 19:53:46
tags: Java并发
---

在学习AQS的出现的LockSupport，秉着知根知底的想法，决定顺带着了解一下LockSupport。

## LockSupport是什么
一个可以创建锁、同步器的基础线程阻塞的底层工具。其工作方式和**Semaphore**十分相似：
1. 调用 *LockSupport.park()* ，将在调用线程中消耗*permit*。如果*permit*可用，那么就会立即返回；否则阻塞调用线程
2. 调用 *LockSupport.unpark()* ，将会使得*permit*可用（注意，这方面和*Semaphore*不同，*Semaphore.release()* 可以叠加*permit*，而*LockSupport.unpark()* 至多只有一个*permit*）

## LockSpport的优势
针对线程的阻塞和解除阻塞，我们很容易想到*Thread.suspend()* 和 *Thread.resume()* 两个方法，然而这两个方法因为天生容易发生**死锁**（suspend()方法原理是暂停JVM，而暂停JVM是不稳定不安全的，所以容易发生问题）从而被抛弃使用。

[具体可以看我的《为什么Thread.suspend和resume被弃用》一文]()

而*Object.wait()* 和 *Object.notify()* 使用起来过于麻烦，因为要放在*synchronized* 块里

所以 *LockSupport* 就成为了很好的替代品

## 使用参数注意事项

* *blocker* 
    - *blocker*在这个类里面主要起到一个线索作用，告诉我们是哪个对象阻塞了当前的线程，方便dump日志进行分析
* *isAbsolute*
    - 如果*isAbsolute* 为true，就是使用Epoch（Unix时间戳），在*LockSupport* 里面对应的方法是parkUntil()；
    - 如果*isAbsolute* 为false，就是使用相对时间（单位纳秒），在*LockSupport*里面对应的方法是parkNanos()

