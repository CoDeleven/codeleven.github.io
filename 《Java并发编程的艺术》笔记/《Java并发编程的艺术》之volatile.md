---
title: 《Java并发编程的艺术》之volatile
date: 2018-05-01 10:52:35
tags: [Java并发, JMM]
---

本章是在学习内存模型后，对*Volatile*关键字 有了更加全面得理解，对知识点进行一个分析总结。

## volatile的特性
volatile在单个操作上和synchronized一样

* 可见性：volatile字段的写操作保证对所有线程可见
* 原子性：volatile字段的单个读写操作是原子性的（比如在32位机上，读取64位的long、double类型），但是volatile++就不具有原子性

## volatile的happens-before
本节采用happens-before关系阐述volatile的作用

```java
int a;
volatile boolean flag;
public void init(){
    a = 1; //①
    flag = true; // ②
}
public void doTask(){
    if(flag){ // ③
        result = a; // ④
    }
    ......
}
```
假设线程A执行init(), 线程B执行doTask()；这个过程里，happens-before关系共分为三类：
1. ① happens-before ②
2. ③ happens-before ④
3. ② happens-before ③

这个过程的happens-before关系图如下所示：
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_happens-before.png)

分别遵守程序次序规则、volatile变量规则和传递规则：

* 程序次序规则：一个线程内，按照代码顺序，书写在前面的操作先行发生于书写在后面的操作
* volatile变量规则：对一个变量的写操作先行发生于后面对这个变量的读操作
* 传递规则：如果操作A先行发生于操作B，而操作B又先行发生于操作C，则可以得出操作A先行发生于操作C

## volatile的内存语义
**JMM针对编译器制定**的volatile的重排序规则
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_reorder_rule.png)

* 第二个操作是volatile写时，不管第一个操作是什么，都不能重排序。这个规则确保volatile写之前的操作不会被**编译器重排序**到volatile写之后。
* 当第一个操作时volatile读时，不管第二个是什么，都不能重排序。这个规则确保volatile读之后的操作不会被**编译器重排序**到volatile读之前。
* 当第一个操作是volatile写，第二个操作是volatile读时，不能重排序。

### volatile的写内存语义
当volatile写发生时，本地内存将刷新主内存。就拿上面happens-before的例子来说，当A线程执行init()写入volatile变量后，B线程执行doTask()读取volatile变量。内存状态变化图如下所示

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_memory_concept.png)

线程A写入flag变量后，本地内存将**更新的共享变量**（更新了几个就刷新几个）刷新至主内存，此时A线程的本地内存和主内存的共享变量相同。

### volatile的读内存语义
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_read_memory_concept.png)

当B线程要读取flag变量时，本地内存B 中包含的共享变量已经被置为无效，B线程不得不去主内存读取共享变量。线程B的读取将导致本地内存B与主内存的共享变量的值变成一致。

将两张图综合起来看，在读线程B读取一个volatile变量后，写线程A在写这个volatile变量之前所有可见的共享变量都将立即变得对读线程B可见。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_memory_summary.png)

### 语义总结
* 当写线程写了一个volatile变量，实质是写线程向接下来要读取这个变量的线程发出了消息（对其共享变量所做的修改）
* 读线程读对应的volatile变量，实质是收到写线程发来的消息（在volatile写之前的共享变量的修改）
* 随后写线程写入volatile变量，读线程去读取volatile变量，这个过程实质是A线程通过主内存给B线程发送消息

## volatile内存语义的实现
volatile关键字实现原理主要还是通过内存屏障进行控制的。编译器在生成字节码时，会在指令序列里插入内存屏障来禁止特定的重排序。对于编译器来说，自行判断最小化插入屏障总数不太可能。为此，JMM采取保守策略：

* 在每个volatile写操作的前面加入*StoreStore*
* 在每个volatile写操作的后面加入*StoreLoad*
* 在每个volatile读操作的后面加入*LoadLoad*
* 在每个volatile读操作的后面加入*LoadStore*

上面的插入策略十分保守，但它可以保证在任意处理器平台上（在X86里，写/写，读/读，读/写 是不会发生重排序的，而且只有StoreLoad一个内存屏障），任意的程序中都能实现正确的语义。


### volatile写的内存语义实现
下面是保守策略下，volatile写插入内存屏障的指令序列示意图。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_write_semantic.png)


StoreStore保证在执行volatile写前，所有写操作的处理已经刷新至内存，保证对其他线程可见了。而StoreLoad的作用是避免后面还有其他的volatile读/写操作发生重排序。由于JMM无法准确判断StoreLoad所处的环境（比如结尾是return），所以有两种选择：

1. 在volatile读前加上StoreLoad
2. 在volatile写后加上StoreLoad

但是因为StoreLoad相比其他内存屏障更加消耗性能，考虑更多场景下是少写多读，所以将StoreLoad加在volatile写后。

讲到StoreLoad的性能问题，不得不提一下Unsafe里面的*putOrderedObject()*。 这个方法很有意思，乍一看命名是放一个有序的对象，但它是通过避免加上StoreLoad内存屏障来弥补volatile写的性能问题。这时可能会有朋友问，不加上volatile不会影响可见性吗？会影响可见性，但不会永远影响下去，最多就两三秒的延迟，就会将共享变量刷新至主内存。所以当延迟要求不高，性能要求高时，就可以采用这个方法（Unsafe不安全类，这个方法的实现在Atmoic***类里面）。

### volatile读的内存语义实现
下面是保守策略下，volatile读插入内存屏障的指令序列示意图。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_read_semantic.png)

LoadLoad保证先执行volatile读再执行后续的读操作（禁止volatile读和后续的读发生重排序），而后的LoadStore保证先执行volatile读再执行写操作（禁止volatile读和后续的写发生重排序）。两者联合起来就是无论如何volatile读必须和程序顺序保持一致。

### volatile执行时的优化
上面的volatile读/写的内存屏障插入策略都十分保守，但是在实际过程中，只要不改变volatile写/读的内存语义，编译器可以根据实际情况省略不必要的屏障。
```java
int a;
volatile int v1 = 1;
volatile int v2 = 2;
void readAndWrite(){
    int i = v1;
    int j = v2;
    a = i + j;
    v1 = i + 1;
    v2 = j + 2;
}
```
针对readAndWrite()方法，编译器在生成字节码时会做如下优化。
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/volatile_read_write_semantic.png)

按顺序下来，第一个volatile读先于第二个volatile，第二个volatile先于所有后续的写，故第一个volatile读一定不会被重排序；StoreStore保证普通写先于第一个volatile写，StoreStore又保证第一个volatile写先于第二个volatile写，最后安全起见插入StoreLoad。

上面的优化针对任意处理器平台，由于不同的处理器有不同“松紧度”的处理器内存模型，内存屏障的插入还可以根据具体的处理器内存模型继续优化。比如X86处理器，由于X86不会对读/读，读/写，写/写做重排序，所以面对X86处理器时，JMM会省略掉三种类型对应的内存屏障，保留StoreLoad内存屏障。

## JSR-133为什么增强volatile的内存语义

在之前的版本，虽然不允许**volatile变量间** 的重排序，但是允许**volatile和普通变量**间的重排序。为了提供一种比锁更轻量级的线程间通信机制，专家组决定增强volatile的内存语义，严格限制volatile变量与普通变量的重排序，确保volatile的写-读和锁的释放-获取具有相同的内存语义。

由于volatile仅仅保证对单个volatile变量的读/写具有原子性，而锁的互斥执行的特性可以确保对整个临界区代码的执行具有原子性。在功能上，锁比volatile更强大；在可伸缩性和性能上，volatile更有优势。具体看《Java理论与实践：正确使用volatile变量》