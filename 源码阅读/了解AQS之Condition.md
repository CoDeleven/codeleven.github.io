---
title: 了解AQS之Condition
date: 2018-04-06 09:54:53
tags: Java并发
---

在实现生产队列和消费队列时，第一个想到的大多数都是*Object.wait()* 和 *Object.notify()* ，而今天要介绍一个*ReentrantLock* 自带的一个工具*Condition*。它相比*Object* 在唤醒方面多了一些可控性，阻塞方面多了一个限时功能。两者的等待唤醒机制几乎一致，宏观流程图如下所示：

![宏观的Condition和Object的等待唤醒机制](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/SimpleConditionObjectWaitFlow.png)

1. 在当前线程A获取到锁
2. 调用对象的等待方法（AQS是Condition.await(),Object是Object.wait()），并进入阻塞
3. 其他线程B获取锁（是不是发现了问题，为什么B线程可以获取锁？）
4. B线程唤醒阻塞的A线程（AQS是Condition.signal()，Object是Object.notify()）；B线程释放锁（如果A线程解除阻塞会做什么？）
5. A线程尝试获取锁（为什么要尝试获取锁？）
6. A线程执行下文
7. A线程释放锁

由于Object的实现机制涉及到*native方法*，所以这里趁机讲解一波AQS的实现过程，我猜测两者的实现原理不会相差太大。这里根据宏观流程图的①、②、③等序号分别进行解释

## 流程详解

1. 当*Condition*对象调用了*await()* 方法时，
![*await()*方法的执行细节](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/whenWait%28%291.png)


```java
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    // 将当前线程封装成结点，加入Condition队列尾部，类似enq()方法，但是在锁内进行await()，不需要CAS
    Node node = addConditionWaiter();
    // 释放当前线程持有的所有锁，在这个操作之后很有可能出现竞态条件
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    // 结点在同步队列里时就返回true
    // 结点在CONDITION队列里时就返回false
    while (!isOnSyncQueue(node)) {
        // 当唤醒线程调用unlock()时就会解除该线程的等待
        LockSupport.park(this);
        /* 第一种情况，该线程被中断，就会将interruptMode设置为THROW_IE
         * 第二种情况，该线程被中断且在检查过程中状态改变（比如中断时，被唤醒），就会将mode设置为REINTERRUPT
         * 第三种情况，该线程被正常signal(notify)，此时结点状态值为0
         */
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    // 加入获取锁的 Sync队列中，获取成功时判断一下mode类型
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    // 如果当前结点有后续结点，那么就清理一下链表
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();    
    if (interruptMode != 0)
        // 这里判断事抛出异常还是简单的中断
        reportInterruptAfterWait(interruptMode);
}
```
在看到```acquireQueued()```时，我们可以知道Condition的要和其他线程一起在同步队列里竞争锁，所以如果想要实现公平竞争，那么可以在```tryAcquire()```方法里实现公平锁，言外之意是Condition也可以是公平竞争的。


```java
final boolean isOnSyncQueue(Node node) {
    // node是CONDITION状态 或者 是CONDITION队列里的第一个
    if (node.waitStatus == Node.CONDITION || node.prev == null)
        return false;
    // 该状态一般发生在两个以上Condition处于wait且被唤醒一个
    if (node.next != null) 
        return true;
    /*
     * node.prev can be non-null, but not yet on queue because
     * the CAS to place it on queue can fail. So we have to
     * traverse from tail to make sure it actually made it.  It
     * will always be near the tail in calls to this method, and
     * unless the CAS failed (which is unlikely), it will be
     * there, so we hardly ever traverse much.
     */
     // 当前结点是尾结点返回true；反之返回false
    return findNodeFromTail(node);
}
```

2. 当其他线程唤醒等待线程，因为这部分比较简单就省略了前面的内容，讲一下重要的地方。
```java
final boolean transferForSignal(Node node) {
    /*
     * 更改node结点的状态；如果更改失败就是已经取消了
     */
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;
    /*
     * 将当前结点接入Sync队列，让这个结点加入等待；如果结点处于取消状态或者CAS
     * 设置状态失败，都会重新唤醒结点所在的线程，重新来过（在这一步会有一些不影
     * 响整体的小错误）
     */ 
    Node p = enq(node);
    int ws = p.waitStatus;
    // 如果这边修改状态失败了，那么就直接唤醒线程；否则交给release()方法来唤醒
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);
    return true;
}
```

3. 阻塞线程被唤醒后，检查结点状态，然后设置interruptMode，最后进入争夺锁的过程里
```java
 private int checkInterruptWhileWaiting(Node node) {
     // 判断是否有中断
     return Thread.interrupted() ?
         (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
         0;
 }
final boolean transferAfterCancelledWait(Node node) {
    if (compareAndSetWaitStatus(node, Node.CONDITION, 0)) {
        // 加入Sync队列，这一步做了signal()做的事
        enq(node);
        return true;
    }

    /*
     * 该线程先被signal()后又被中断，我们就等该signal()流程结束。
     * 因为transfer过程不会太长，就选择自选
     */
    while (!isOnSyncQueue(node))
        Thread.yield();
    return false;
}
```
```java
// 这里是await()的后半部分

// 加入锁的获取，因为后半部分还有lock.unlock()，所以必须要重新获取锁
if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
    interruptMode = REINTERRUPT;
if (node.nextWaiter != null) // clean up if cancelled
    unlinkCancelledWaiters();
if (interruptMode != 0)
    // 如果该线程是被中断的，那么就重新抛出异常
    // 如果该线程是被唤醒且中断的，那么就重新设置中断标志，交给程序员自己处理
    reportInterruptAfterWait(interruptMode);
```

## 总结
AQS的锁机制主要依靠双向的链表，而Condition的等待唤醒机制只需要普通链表即可实现。
这里对整体流程又进行了个总结。
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/summary4AQS_Condition.png)
