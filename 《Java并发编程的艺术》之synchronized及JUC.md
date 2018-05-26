---
title: 《Java并发编程的艺术》之synchronized及JUC
date: 2018-05-02 10:36:31
tags: [Java并发, JMM]
---

## synchrnoized的happens-before
```java
int a;
boolean flag;
public synchronized void init(){// ①
    a = 100; // ②
    flag = true; // ③
}// ④
public synchronized void doTask(){ // ⑤
    if(flag){ // ⑥
        int result = a; // ⑦
    }
} // ⑧
```
假设线程A执行init()，线程B执行doTask()，有如下的happens-before关系：

* 根据程序次序规则：
     - ① hb ②
     - ② hb ③
     - ③ hb ④
     - ⑤ hb ⑥
     - ⑥ hb ⑦
     - ⑦ hb ⑧
* 根据监视器规则：
     - ① hb ④
     - ④ hb ⑤
     - ⑤ hb ⑧

根据传递规则，保证init()方法所有的修改对doTask()方法可见，happens-before关系如下所示
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/synchronized_happens_before.png)

1、2间的表示程序次序性规则，4、5间的表示监视器规则，由于3、4有happens-before关系，4、5有happens-before关系，所以根据传递性规则，2、6间有happens-before关系。

线程A释放锁之前所有可见的共享变量，在线程B获取同个锁之后就变得可见了。

## synchrnoized的内存语义

### synchrnoized获取锁内存语义
当释放锁时，JMM会把线程对应的本地内存中的共享变量刷新到主内存。以上面的例子为例，共享数据的状态示意图如下所示
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/synchronized_release_semantic.png)

### synchrnoized释放锁内存语义
当A线程获取到锁时，JMM会把该线程对应的本地内存置为无效。从而使得被监视器保护的临界区代码必须从主内存中读取共享变量。

![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/synchronized_lock_semantic.png)

### 语义总结
对比锁释放-获取的内存语义和volatile的写-读内存语义可以看出：锁释放与volatile写有相同的内存语义；锁获取和volatile读有相同的内存语义。

* 线程A释放一个锁，实质上是告诉其他 要获取该共享变量 线程 一个消息（线程A所做的修改）
* 线程B获取一个锁，实质上是接受到其他线程发出的消息（释放这个锁的线程对共享变量所做的修改）
* 线程A释放，随后线程B获取，实质上是线程A通过主内存给线程B发送消息。

这里判断语义是否相同是通过两个操作的流程是否相同，比如线程A的锁释放完时，刷新至主内存；volatile写完后，刷新至主内存，并通知其他线程本地内存的共享变量失效（在锁释放环节里是交给锁获取执行）；

## CAS和JUC
synchronized是通过控制对象头来控制锁的升级，但是具体获取锁和释放锁的流程藏在JVM里，这里将通过ReentrantLock类比synchronized过程。

[ReentrantLock的实现流程](https://codeleven.cn/2018/04/05/%E4%BA%86%E8%A7%A3AQS%E4%B9%8BExclusiveLock/)

这里要学习的是CAS，JDK文档对该方法的说明如下：如果当前状态值等于预期值，则以原子方式将同步设置为给定的更新值。此操作具有volatile读和写的语义。
前面讲到volatile写保证volatile写不会和前面的操作发生重排序，volatile读保证volatile读不会和后面的操作发生重排序。组合这两个条件就意味着同时实现了 禁止某一操作和操作前、操作后的重排序。CAS操作就是如此，它在是通过加上lock前缀来实现以下的功能：
* 使用缓存锁定保证原子性
* 禁止之前和之后的重排序
* 把写缓冲区中的所有数据刷新到内存

正是因为CAS同时具有volatile读和写的内存语义，因此Java线程之间的通信有下面四种方式。

1. A线程写volatile变量，B线程读这个volatile变量
2. A线程写volatile变量，B线程用CAS修改volatile变量
3. A线程用CAS修改volatile变量，B线程用CAS修改这个变量
4. A线程用CAS修改volatile变量，B线程用volatile读取该变量

JUC包的通用化的实现模式：
* 声明共享变量为volatile
* 使用CAS的原子条件来实现线程间的同步
* 配合volatile读/写和CAS 来实习线程间的通信

AQS，非阻塞数据结构和原子变量类，这些JUC包中的基础都是使用上面的模式来实现的，而JUC包的高层类又是依赖这些基础类来实现的。从整体看，JUC包的实现示意图如下所示。

![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/JUCStructure.png)

