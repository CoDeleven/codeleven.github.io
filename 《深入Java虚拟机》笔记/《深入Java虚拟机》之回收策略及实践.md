---
title: 《深入Java虚拟机》之回收策略及实践
date: 2018-06-05 22:35:31
tags: JVM
---

新生代分为Eden区和Survivor区，Survivor会按1：1划分成From、To两个区域。示意图如下所示

![新生代布局](https://blog-1252749790.file.myqcloud.com/jvm/YoungGen.png)

## 新生代比例划分
布局比例会按 `-XX:SurvivorRatio=x` 划分，这个虚拟机参数是指 **Eden区:Survivor区=z** ，即Eden区和Survivor区之比为x。计算方式如下：
    
> z * x + 2 * x = 新生代大小

    如果z = 6，新生代大小为10240K，那么6 * x + 2 * x = 10240K，解出x = 1280K；那么Eden区的大小就是7680K？？？

理论上的确是7680K，但是当该数值除以1024时，无法得到整数值（个人猜测为了内存对齐吧）。所以实际上Eden区的大小为8192K，即8MB。

    如果z = 6， 新生代大小为102400K（100MB），那么6 * x + 2 * x = 102400K，解出x = 12800K，那么Eden区就是76800K？

嗯，真的是76800K。

总而言之，解出来的Eden区数值（单位一定是K）如果无法被整出，则向上取一个能被1024整除的数。

## 内存分配规则
![GC流程示意图，不严谨版](https://blog-1252749790.file.myqcloud.com/jvm/GC_flowchart.png)

当直接分配对象时，优先考虑 `Eden区`。如果不能则考虑是否能直接放入 `Old Gen`，由 `-XX:PretenureSizeThreshold`控制多大的对象能直接进入 `Old Gen`。如果仍不能放入 `Old Gen` 则触发minor GC。发生 minor gc时，就先清空Eden区和其中一块Survivor区，然后放入另外一块空的里面（注意这里针对发生过一次GC以上的情况）。

### 要点一
对象优先在Eden区分配，如果Eden区不够分配了，剩余空间已经不足以分配新对象了，因此发生Minor GC。GC期间，发现已有的对象都不能全部放入Survivor空间，所以只能通过`分配担保机制`提前转移到 `Old Gen`。


### 要点二
当分配一个大对象。打对象容易导致内存还有不少空间就提前触发垃圾收集以获取足够大的空间安置它们。虚拟机提供了 `-XX:PretenureSizeThreshold`参数，当对象的大小大于等于设置的参数时，对象就会直接被分配到 `Old Gen`。该参数只对 `Serial` 和 `ParNew`两款收集器有效。

### 要点三
虚拟机给每个对象定义了一个年龄计数器字段 `Age`，该字段会记录 自从Eden出生后，经过Minor GC 的次数。每经过一次 Minor GC，Age就会加一，当它的年龄到达15时，就会晋升到 `Old Gen`。晋升年龄可以用参数 `-XX:MaxTenuringThreshold`控制。

### 要点四
如果Survivor空间里有一半及以上的对象年龄相同，那么大于等于该年龄的对象可以直接进入Old Gen，无须等待`-XX:MaxTenuringThreshold`的参数

### 要点五
在发生Minor GC之前，虚拟机会先检查老年代最大可用的连续空间 是否 大于新生代所有对象总空间。
如果这个条件成立，那么Minor GC的担保可以确保是安全的。
如果这个条件不成立，则设置`-XX:+/-HandlePromotionFailure`允许担保，那么发生minor gc 前，会判断一下 **老年代最大可用连续空间** 是否大于 **历次晋升到老年代的平均大小**。如果大于，那么会尝试发生一次Minor GC（不确定是否安全的）；如果小于，或者没有开启 `-XX:+/-HandlePromotionFailure`，就发生 Full GC。

一般都会开启 `-XX:+/-HandlePromotionFailure` ，因为即使条件不满足，也要尝试进行一次 Minor GC；否则直接进行 Full GC，对系统的负担就会比较大。
在JDK6 Update24之后，`-XX:+/-HandlePromotionFailure`参数已经失效了，默认为：**老年代的连续空间** 大于 **新生代对象总大小** 或者 **大于历次晋升的平均大小**就发生Minor GC

-------------------

> 而是将内存分为一块较大的Eden区和两块较小的Survivor空间里，每次使用Eden和其中一块Survivor。

上面的句子摘自《深入Java虚拟机 第二版》，这句子可能会给一些读者带来误解：以为Survivor也会作为一块内存空间用来 **分配** 对象。这直接会让我们以为当 `其中一块Survivor`和`Eden区`都满了后才会触发Minor GC。其实不然，在HotSpot虚拟机里，所有新生对象都是闲分配到 `Eden区`中（特殊情况分配到 `Old Gen`）。当`Eden区`不够，触发了Minor GC后，会将 `Eden区` 里的幸存对象复制到 `Survivor的From区`里。在第一次Minor GC后，对象才 **真真正正的只在Eden区和其中一块Survivor里**。**即发生第一次Minor GC前，只有Eden区存放对象**


## 实践阶段
emmmmmm，以后补充；

1. 当新分配的对象直接超出了`Eden区`的可用最大值时，直接放入`OldGen`
```java
-Xms20M  // 最小内存20M
-Xmx20M  // 最大内存20M
-Xmn18M  // 年轻代10M，老年代也就10M
-XX:SurvivorRatio=8  // eden区比例，如果为8，就是8：1：1；如果为3，就是3：1：1
-XX:+PrintHeapAtGC // 打印GC前后的信息
```



