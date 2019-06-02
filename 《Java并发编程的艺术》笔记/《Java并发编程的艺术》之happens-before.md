---
title: 《Java并发编程的艺术》之happens-before
date: 2018-05-05 10:32:09
tags: [Java并发, JMM]
---

**happens-before** 是JMM的核心概念

## JMM的设计

* 程序员对内存模型的使用。程序员希望内存模型简单易用、易于理解，程序员需要一个强内存模型（尽量偏向顺序一致性）编写程序
* 编译器和处理器对内存模型的实现。编译器和处理器希望内存模型对它们的束缚越小越好，编译器和处理器需要一个弱内存模型（尽量远离顺序一致性）

所以JSR-133专家组在设计JMM时候就需要找到一个平衡点：一方面要保证程序员的简单易用性，一方面要保证对处理器和编译器的限制尽可能放松。

```java
int a = 1; // ①
int b = 2; // ②
int result = a * b; //③
```
上述代码的happens-before关系如下所示：
1. ① happens-before ③
2. ② happens-before ③
3. ① happens-before ②

其中1、2是必须遵守的，3是不必要的。因此JMM将重排序分为以下两类：
1. 会改变程序执行结果的
2. 不会改变程序结果的

而针对这两类，JMM分别进行以下的处理：
1. 会改变程序执行结果的，JMM坚决禁止
2. 不会改变程序结果的，JMM尽可能放松限制

happens-before其实就是一剂安慰剂。程序员遵守happens-before的规则，JMM为其提供内存可见性，happens-before对程序员来说看似是禁止了除规定以外的内容，实际上允许编译器和处理器对**不改变程序结果的内容**都进行了重排序。

happens-before是一个中间产物，从上往下看，它是基础，是规则；从下往上看，它是限制，是约束；所以讨论happens-before的时候一定要讲清楚是哪个视角！（这里以前纠结了很久）

## happens-before的定义
1. 如果一个操作happens-before另一个操作，那么第一个操作的执行结果将对第二个操作可见，而且第一个操作的执行顺序排在第二个操作之前。
2. 两个操作之间存在happens-before关系，并不意味着Java平台的具体实现必须要按照happens-before关系指定的顺序来执行。如果重排序之后的结果，与按照happens-before关系来执行的结果一致，那么这种重排序并不非法(也就是说JMM允许这种重排序)

as-if-serial语义保证单线程内执行结果不被改变，happens-before保证正确同步下多线程的程序执行结果不被改变。

## happens-before有哪些规则
1. 程序顺序性规则：一个线程中的每个操作，happens-before于同个线程中任意后续的操作。
2. 监视器锁规则：对一个锁的解锁，happens-before于随后对这个锁的加锁
3. volatile变量规则：对一个volatile的写，happens-bfore于任意后续对volatile的读
4. 传递性：如果A happens-before B，且B happens-bfore C，那么 A happens-before C
5. start()规则: 如果A线程执行ThreadB.start()，那么A线程的ThreadB.start()操作happens-before于线程B的任意操作
6. join()规则：如果A线程执行ThreadB.join()并成功返回，那么线程B中的任意操作happens-before A线程从ThreadB.join()操作成功返回。


### 规则举例一
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/happensbefore_start.png)

按照程序顺序规则，操作1 happens-before 2、3 happens-before 4，其中因为start规则，2 happens-bfore 3。最后根据传递性规则，1 happens-before 4。这意味着操作1 保证对 操作2 可见。

### 规则举例二
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/happensbefore_join.png)

按照程序顺序规则，1 happens-before3、 4 happens-before 5，而join规则要求3 happens-before 4，所以最后根据传递性规则，1 happens-before 5。这意味着操作 1 保证对操作5 可见