---
title: 了解AQS之SharedLock
date: 2018-05-09 22:49:13
tags: Java并发
---

前面已经学习过AQS的exclusive和condition两个模式，现在要把最后的shared模式看完。此次从shared的实现类——ReentrantReadWriteLock 开始分析。

共享的特性：

![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/shareMode.png)
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/exclusiveMode.png)

如果先获取到线程锁，那么独占锁就要等待；如果先获取独占锁，那么共享锁就要进入等待。对于共享锁来说，顾名思义大家可以一起访问这个资源（读）；对于独占锁来说，要想访问只能一一排队，一个个来修改，保证每次修改后的可见性。

前面提到AQS是通过同步队列来管理同步状态的，而状态state只有一个变量，要想记录读/写两个状态，就只能将state拆分成2个16位，如下图所示

![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/reentrantreadwritelock_state.png)

高16位表示读状态，低16位表示写状态。比如获取读状态：```state >>> 16```，获取写状态：```state & 0X0000FFFF```，根据状态划分可以得出以下结论：
当state不为0时而state低16位为0，则表示读锁已经被获取；当state不为0而state高16为0时，则表示写锁已经被获取。

## 写锁的获取与释放
写锁是一个可重入的排他锁。如果当前线程已经获取了写锁，则增加写状态。如果当前线程在获取写锁时，读锁已经被获取了或者该线程不是持有写锁的线程，则当前线程进入等待状态。
```java
protected final boolean tryAcquire(int acquires) {
    Thread current = Thread.currentThread();
    int c = getState();
    int w = exclusiveCount(c);
    if (c != 0) {
        if (w == 0 || current != getExclusiveOwnerThread())
            // 读锁已经被获取
            return false;
        if (w + exclusiveCount(acquires) > MAX_COUNT)
            // 重入次数超过最大值
            throw new Error("Maximum lock count exceeded");
        // 重入
        setState(c + acquires);
        return true;
    }
    // writerShouldBlock是由子类实现的策略
    // 如果writer是非公平锁，那么就一直返回false
    // 如果writer是公平锁，那么就通过hasQueuedPredecessors()判断
    if (writerShouldBlock() ||
        !compareAndSetState(c, c + acquires))
        return false;
    // 设置唯一
    setExclusiveOwnerThread(current);
    return true;
}
```
该方法除了重入溢出的判断外，还增加了是否已经存在读锁的条件判断。如果存在读锁，则写锁不能被获取，原因在于：读写锁要确保写锁的操作对读锁可见，如果允许读锁在已被获取的情况下对写锁的获取，那么正在运行的其他读线程无法得知当前写线程的操作。写锁的缩放和ReentrantLock的释放过程基本类似，每次释放减少写状态，当写状态为0时表示写锁已经被释放。


## 读锁的获取与释放
读锁时一个支持重入的锁，它能够被多个线程获取，在没有其他写线程的访问时，读线程总会被成功获取，而所做的也只是增加读状态。如果当前线程已经获取了读锁，则增加读状态。如果当前线程在获取读锁时，写锁被其他线程获取，则进入等待状态。读状态保存的是总的读次数，每个线程的读取状态由ThreadLocal进行保存。
```java
protected final int tryAcquireShared(int unused) {
    Thread current = Thread.currentThread();
    int c = getState();
    // 写锁已经被获取，直接返回
    if (exclusiveCount(c) != 0 &&
        getExclusiveOwnerThread() != current)
        return -1;
    int r = sharedCount(c);
    // 根据队列策略，参考写锁；
    // 读锁个数不超过最大值
    if (!readerShouldBlock() &&
        r < MAX_COUNT &&
        compareAndSetState(c, c + SHARED_UNIT)) {
        // 读锁个数等于0
        if (r == 0) {
            firstReader = current;
            firstReaderHoldCount = 1;
        } else if (firstReader == current) {
            firstReaderHoldCount++;
        } else {
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        return 1;
    }
    // 如果前面都不满足条件，进入该方法，自选到成功获取读锁
    return fullTryAcquireShared(current);
}
```

如果这一步获取失败，那么就会转入```tryAcquireShared()```，这一步和```acquireQueued()```很像，唯一的区别在于```setHeadAndPropagate()```这方法
```java
private void setHeadAndPropagate(Node node, int propagate) {
    // 保存头结点
    Node h = head;
    // 设置头结点
    setHead(node);
    // propagate大于0 OR 头结点为空 OR 头结点的状态 < 0 OR 重新获取头结点时的状态
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
        (h = head) == null || h.waitStatus < 0) {
        // 获取当前结点的下个结点并唤醒它（因为独占锁，后面的共享锁阻塞；
        // 当独占锁被释放后，共享锁的结点应该苏醒）
        Node s = node.next;
        // 该操作会唤醒不必要的结点，但是为了避免多线程发生竞争，所以需要尽可能快的通知其他线程
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```

读锁的每次释放会将读状态减去值```1 << 16```

## 锁降级
锁降级不是获取写锁，释放，再获取读锁（不是分段的）；而是先获取写锁，再获取读锁，释放写锁（是交叉的）。


## 总结
ReentrantReadWriteLock是独占锁和共享锁的合体，在write方面是独占的，read方面是共享的，因为有两个锁，为了管理两个状态，提出了划分高16位作为读状态，低16位作为写状态