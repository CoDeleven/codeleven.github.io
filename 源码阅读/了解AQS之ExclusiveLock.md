---
title: 了解AQS之ExclusiveLock
date: 2018-04-05 19:57:27
tags: Java并发
---

## 1.1 AQS简介
相比重新造个轮子来管理内部线程状态，AQS提供了一个稳定的、多面（排斥锁，Condition及共享锁）的线程状态管理框架。AQS是一个由FIFO队列构成的同步框架，主要用于构建自定义的同步器，比如*ReentrantLock*等常见的同步器。它的整体方法流程如下所示：

![排斥锁方法流程图](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/exclusiveLockIntroduction.png)


## 1.2 AQS要点
AQS的结构和**CLH(Craig, Landin, anHagersten)自旋锁队列** 很像，但AQS是阻塞的队列而CLH是自旋的队列。

```java
static class Node{
    /**
     * 等待状态，用来判断当前的线程是否需要阻塞
     */
    volatile int waitStatus;
    /**
     * 前一个结点
     */
    volatile Node prev;
    /**
     * 后一个结点，当该结点释放了锁后，通知后一个结点
     */
    volatile Node next;
    /**
     * 当前结点所代表的线程
     */
    volatile Thread thread;
    /**
     * 后一个节点，用于condition的情况下
     */
    Node nextWaiter;
    /**
     * 获取前一个结点
     */
    predecessor():boolean;
}
```


## 1.3 排斥锁
为了方便后续讲解，这边给出场景：

现在有A、B、C、D四个线程同时抢占同一个锁实例。

为了方便讲解, 假设A线程会先抢到锁，我们对A线程获取锁的过程进行解析;B、C、D线程作为结点依次加入等待队列（队列里顺序按B、C、D来，方便点）

### 1.3.1 上锁

1. 当调用ReentrantLock.lock() 时，首先会调用AQS的acquire() 方法并传入数值1。
```java
public final void acquire(int arg) {
    // tryAcquire()是留给子类实现的，先让当前线程尝试获取锁，如果获取锁失败就会将当前线程封装到等待队列里
    // 调用子类的tryAcquire()
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

2. *ReentrantLock.tryAcquire()* 会调用其内部的*Sync.nonfairTryAcquire()*，并对加锁的个数进行计算。
![非公平锁下的tryAcquire()方法流程图](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/nonfairTryAcquire%28%29.png)

* ① 传入的*acquires* 参数是想请求的锁个数，这个参数的值是由子类决定的，在*ReentrantLock* 里面这个值均为1
* ② 在*ReentrantLock* 里面（不同的实现*state* 意义不同），***state*是否为0代表锁是否被持有**
* ③ 当*state == 0* 时，调用*compareAndSetState()* 尝试设置*state* 为1。成功则设置当前线程为锁拥有者，并返回true；否则返回false
* ④ 当*state != 0* 时，判断是否是当前线程持有锁
* ⑤ 当前线程已经持有该锁了，那么重入该锁，*state* 值递增1，最多重入Integer.MAX_VALUE次。注意，当*state > 0 && state != 1* 的情况下，释放一次锁是无法完全释放的，只有释放*state* 次锁，让*state* 为0，才能完全释放锁

```java
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    // 该锁尚未被持有
    if (c == 0) {
        /* 非公平锁：
         *    将state设置为acquires的值，谁能抢到就是谁的
         *    想不通的这样想：头结点唤醒了后继结点
         *    此时另外一个节点插了进来，发生竞争，可能新插进来的结点获取到锁
         *    也可能是后继结点获取到锁
         * 公平锁：
         *    将锁让给等待时间最长的结点
         *    一般来说是让给头结点的后继结点（因为FIFO）
         */
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

3. 到这一步，A线程顺利拿到锁去执行它的任务了，而B、C、D三线程就会因为*tryAcquire()* 返回false而执行后续的内容：*addWaiter()*

```java
private Node addWaiter(Node mode) {
    // 创建结点，mode用来控制是共享锁、还是排斥锁
    Node node = new Node(Thread.currentThread(), mode);
    Node pred = tail;
    // 是否存在尾结点
    if (pred != null) {
        // 新结点放在尾结点后端
        node.prev = pred;
        // 重新设置尾结点（原子操作）
        if (compareAndSetTail(pred, node)) {
            /* 尾结点的next域指向新结点
             * 这里会发生竟竞态条件？
             * 竞态条件典型的一个例子就是“条件判断失效”
             * 因为CAS的原子性，条件不会失效，保证一次只有一个线程执行成功
             * 注意CAS无法保证ABA问题
             */
            pred.next = node;
            return node;
        }
    }
    // 第一次发生竞争（或者设置尾结点竞争失败）进入enq()
    enq(node);
    return node;
}
```

4. 因为B、C、D线程均会进入**未初始化**的等待队列，所以**至少有一个结点**会进入*enq()* 方法。*enq()* 方法很简单，就是创建一个空结点作为头结点来初始化等待队列（有人可能会问那A线程呢？不用封装成结点吗？别急，往下看），其余**CAS 竞争失败的结点插入尾结点后**。

```java
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) { 
            // Must initialize
            /* 为什么要在这里初始化，而不是一开始就初始化队列？
             * 因为如果没有发生竞争，就永远不会产生等待队列
             * 所以将初始化放到产生竞争的时候
             */
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            // 要入队的结点插入尾结点
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```
在addWaiter结束后：
![addwaiter结束](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/afterEnq.png)

5. 在*addWaiter()* 方法结束后，准备通过*acquireQueued()* 开始尝试获取锁。B结点获取新建的空结点（即上文新建的头结点），然后B线程*tryAcquire()* ，众所周知，A线程正持有锁，所以B线程*tryAcquire()* 失败，然后进入*shouldParkAfterFailedAcquire()* 

```java
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            // 获取当前结点的前驱结点
            final Node p = node.predecessor();
            // 判断p是否是头结点，如果p是头结点，尝试获取
            // 否者根据p判断变量node是否需要阻塞
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
            }
    } finally {
        if (failed)
            /*
             * 设置结点状态为CANCEL
             * 当获取锁时抛出了异常或者超出时限
             * 那么就为当前结点设置CANCELLED
             */
            cancelAcquire(node);
    }
}
```

6. 该方法主要根据前驱结点判断当前结点是否需要阻塞，因为当前所有结点的状态都是初始化状态（ws为0）。每个结点在第一次失败后，都会进入*else块*（除非执行*acquireQueued()里的tryAcquire()* 成功）。*else块* 里会将前驱结点设置为*SIGNAL* 状态，暗示**下一次你要是还是获取失败，你就乖乖阻塞吧**

```java
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node){
    int ws = pred.waitStatus;
    // 前驱结点pred是SIGNAL状态，所以需要让当前结点node阻塞
    if (ws == Node.SIGNAL)
        return true;
    // 前驱结点pred是CANCELLED状态
    if (ws > 0) {
        /*
         * Predecessor was cancelled. Skip over predecessors and
         * indicate retry.
         */
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    // 前驱结点pred状态是0或者PROPAGATE
    } else {
        // 更新前驱结点pred的状态为SIGNAL，在下一次尝试获取锁的时候对该结点进行阻塞
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```
![shouldParkAfterFailedAcquire后](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/afterShouldParkAfterFailedAcquire.png)

7.此时除了尾结点外，其他结点的*waitStatus域* 均为SIGNAL。但除了头结点（Empty结点）外的所有结点包含的线程都处于阻塞状态，并等待它们各自的前驱结点来唤醒自己

### 1.3.2 释放锁
本节内容将会连接着1.3.1节的内容，前面讲到除了那个空的头结点外，其他结点包含的线程都发生了阻塞。那么A线程不在队列内该如何唤醒B呢？

1. 当A线程调用了*ReentrantLock.release()* (其实是AQS的release)

```java
public final boolean release(int arg) {
    // 调用子类的实现
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```
```java
protected final boolean tryRelease(int releases) {
    // 计算当前线程持有锁的个数
    int c = getState() - releases;
    // 防止未持有锁的线程瞎搞
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    setState(c);
    return free;
}
```

2. 细心的小伙伴可能已经注意到*tryRelease()* 传入的参数，如果*state域* 减去 *releases参数* 不为0，依然无法释放锁。这个特性和*CountDownLatch*很像，当持有的数字为0时才能释放。

3. 假设现在*tryRelease()* 返回true，接下来就判断头结点是否为空且状态是否为0（如果为0，代表后面没有结点需要唤醒）。如果B结点运行到*acquireQueued()里tryAcquire() 和 shouldParkAfterFailedAcquire()* 间时，A线程调用了*release()* 会发生问题吗？<br/>不会，因为在这种情况下头结点的*waitStatus域* 如果是0，B结点还有机会可以再次*tryAcquire()* ，如果是SIGNAL，那就对头结点调用后续的*unparkSuccessor()* 

```java
private void unparkSuccessor(Node node) {
    int ws = node.waitStatus;
    if (ws < 0)
        compareAndSetWaitStatus(node, ws, 0);
    /*
     * 获取头结点后面的结点s
     * 如果结点s是null或者s已经被取消了
     * 就从后往前遍历，直到找到一个满足条件的结点
     */
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            // 不用担心被唤醒的结点不是头结点，在acquireQueue方法里会重新设置
            if (t.waitStatus <= 0)
                s = t;
    }
    // 唤醒结点
    if (s != null)
        LockSupport.unpark(s.thread);
}
```

4. 在A线程释放了锁后。如果没有新的线程要竞争，那么锁不出意外就是B线程的；否则，在非公平锁的实现里，鹿死谁手还不知道（公平锁里不出意外也一定是B线程的）

### 1.3.3 取消/中断
本节介绍方法*cancelAcquire()*，该方法都出现在最后的*finally块*中，而且需要*failed域* 为true（获取锁失败），才会进入*cancelAcquire()* ，所以最终需要取消的结点，要么是**定时器到时间**了，要么是**线程被中断**了。废话不多说，看初始图。

![设置取消状态](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/cancelAcquire1.png)
图表解释：
* A结点：采用lock()方法，并且获取锁成功
* B结点：采用tryLock()方法，并设置好10秒的期限，一到10秒就取消获取锁，当前处于阻塞状态
* C结点：操作同B线程
* D结点：采用lock()方法，获取锁失败，处于阻塞状态


```java
/**
 * 10s过后，假设A线程仍持有锁，而B线程的tryLock()到期，那么B线程因为
 * throw new InterruptedException()而跳出for循环进入finally块，准备执行
 * cancelAcquire()
 * PS:此情况下C尚未到期，因为方便写:)
 */
private void cancelAcquire(Node node) {
    if (node == null)
        return;
    node.thread = null;
    // 获取当前结点的前驱结点
    Node pred = node.prev;
    /* 判断前驱结点是否为取消状态；
     * 如果是取消状态的话，就一直向前查找，直到找到非CANCELLED状态的结点
     */
    // 本示例里pred是A结点
    while (pred.waitStatus > 0)
        node.prev = pred = pred.prev;
    
    Node predNext = pred.next;
    /* 不管三七二十一，来了这个方法，这个结点就注定要设置成CANCELLED
     * 那会不会有其他线程同时对这个结点的状态进行操作？
     * 有也没关系，它的顺序无论在其他CAS写操作之前还是之后最终都会设置为
     */
     CANCELLED(注意是“CAS”写操作)
    // ①到这一步，本示例里B结点的ws转为CANCELLED 
    node.waitStatus = Node.CANCELLED;
    // 如果当前结点是尾结点，那么就将predNext（从后到前第一个非CANCELLED状态的结点）设置为尾结点
    // 本示例里B结点不是尾结点，跳过if进入else
    if (node == tail && compareAndSetTail(node, pred)) {
        compareAndSetNext(pred, predNext, null); 
    } else {
        int ws;
        // 如果pred不是头结点，就设置状态为SIGNAL
        if (pred != head &&
            ((ws = pred.waitStatus) == Node.SIGNAL ||
             (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&pred.thread != null) {  
            Node next = node.next;
            /* 当前结点是否有后继结点
             * 若有后继结点且不是CANCELLED状态，则将后继结点和pred相连
             */
            if (next != null && next.waitStatus <= 0)
                compareAndSetNext(pred, predNext, next);
        /* 
         * 如果pred是头结点就唤醒后继的非CANCELLED结点
         */
        } else {
            // ② 唤醒后面的非CANCELLED状态的结点
            unparkSuccessor(node);
        }
        /* 很骚的操作，一般都是设置null来help gc，这里采用循环引用当新一波的  
         * tryAcquire()之后，会将CANCELLED的引用清理掉，所以最后就变成不可达的
         * 引用，自然就被gc了
         */
        node.next = node; 
    }
}
```
流程图大致是这样的:
![最后的状态](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/cancelAcquire2.png)

到这里，整个*cancelAcquire()* 的流程结束了，最后的*unparkSuccessor()* 方法最终也不是为了唤醒C，具体的可以参考前面的*release()*一节

## 1.4 lock的其他方式
*ReentrantLock* 除了*lock()* 之外还有*tryLock()*和*lockInterruptibly()*。

* *tryLock(long, TimeUnit)* -> 在一定时间内没有获得锁就放弃获取锁
* *lockInterruptibly()* -> 获取锁的过程中可以被中断

### 1.4.1 tryLock
1. 调用*tryLock()*
```java
// ReentrantLock
public boolean tryLock(long timeout, TimeUnit unit)
        throws InterruptedException {
    return sync.tryAcquireNanos(1, unit.toNanos(timeout));
}
```
2. 先检查中断状态，然后至少调用一次tryAcquire()。个人理解：如果当前锁没有发生竞争，不需要再额外创建等待队列。所以预先判断锁是否被持有，可以降低资源消耗

```java
public final boolean tryAcquireNanos(int arg, long nanosTimeout)
        throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    return tryAcquire(arg) ||
        doAcquireNanos(arg, nanosTimeout);
}
```

3. 没有什么特别之处，再*acquireQueued()* 基础上加了时限。唯一注意的点就是这里用到了自旋，在时间没超过*spinForTimeoutThreshold域* 之前，一直处于for循环（其实也就1000纳秒的时间处于自旋）。当超过自旋时间，进入*LockSupport.parkNanos()*，故名思意，不多介绍，想了解的可以看我的*LockSupport*文章

```java
private boolean doAcquireNanos(int arg, long nanosTimeout)
        throws InterruptedException {
    // 设置的时间小于0，直接返回
    if (nanosTimeout <= 0L)
        return false;
    // 期限，绝对时间    
    final long deadline = System.nanoTime() + nanosTimeout;
    // 创建一个新的结点，注意EXCLUSIVE
    final Node node = addWaiter(Node.EXCLUSIVE);
    boolean failed = true;
    try {
        for (;;) {
            final Node p = node.predecessor();
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return true;
            }
            nanosTimeout = deadline - System.nanoTime();
            // 如果当前时间超过了时限，就当获取锁失败，返回false
            if (nanosTimeout <= 0L)
                return false;
            /* 前面和acquireQueued() 一样，后面是允许自旋的时间
             * 再没达到spinForTimeoutThreshold前，一直处于循环
             */
            if (shouldParkAfterFailedAcquire(p, node) &&
                nanosTimeout > spinForTimeoutThreshold)
                // 限时阻塞的主要逻辑
                LockSupport.parkNanos(this, nanosTimeout);
            // 可以中断    
            if (Thread.interrupted())
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

### 1.4.2 lockInterruptibly
原本计划着要写，但是内容差不多，为了缩短篇幅，就算了。读者有兴趣可以去看看。

## 1.5 小栗子
占坑，以后想到了来写

## 1.6 总结
AQS总体给人的感觉就是提供了一个管理线程状态的框架，而这个框架是基于先进先出的链式队列，而这个队列主要是以阻塞为主，和CLH以自旋为主的队列不同，因为暂时没接触太多的并发项目，想写关于AQS的小栗子也没什么头绪，干脆在这里留个坑，以后有了回来填。