---
title: 了解AQS之Condition
date: 2018-04-06 09:54:53
tags: Java并发
---

在实现生产队列和消费队列时，第一个想到的大多数都是*Object.wait()* 和 *Object.notify()* ，而今天要介绍一个*ReentrantLock* 自带的一个工具*Condition*。

## 流程详解

1. 当线程获取到锁并调用*Condition.await()* 时
```java
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    // 将当前线程封装成结点    
    Node node = addConditionWaiter();
    // 释放当前线程持有的锁
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```
```java
private Node addConditionWaiter() {
    // 获取Condition队列里最后一个结点
    Node t = lastWaiter;
    // If lastWaiter is cancelled, clean out.
    if (t != null && t.waitStatus != Node.CONDITION) {
        unlinkCancelledWaiters();
        t = lastWaiter;
    }
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    if (t == null)
        firstWaiter = node;
    else
        t.nextWaiter = node;
    lastWaiter = node;
    return node;
}
```