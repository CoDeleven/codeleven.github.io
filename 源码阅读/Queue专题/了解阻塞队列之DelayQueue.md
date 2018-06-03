---
title: 了解阻塞队列之DelayQueue
date: 2018-06-03 12:10:50
tags: [Java集合]
---

DelayQueue的主要功能是取出超出时间期限的元素，在缓存方面能发挥较好的效果。
DelayQueue包含以下几个属性：
* lock:ReentrantLock ----- 不解释
* q:PriorityQueue ----- 存放元素的队列，该队列会根据比较器进行排序，在DelayQueue里就是按剩余时间进行排序
* leader:Thread ----- Leader-Follower线程模型，主要用于降低锁力度，不需要消息队列。
* available:Condition ----- 不解释


DelayQueue的整体结构采用代理模式，如图所示：
![DelayQueue的继承关系图](https://blog-1252749790.file.myqcloud.com/collections/DelayQueue_Structure.jpg)

其中有一种新的线程设计模式叫 [Leader-Follower](http://ifeve.com/leader-follower-thread-model/)：

* 有一条线程负责监视是否有任务到达，该线程叫Leader
* 其余线程处于Follower状态（await状态），时刻准备着被唤醒成为下一个Leader
* 当Leader线程检测到任务到达后 **进入处理状态** 并 **唤醒等待的Follower线程之一**
* 当老Leader线程（现在处于Process状态）处理完毕后，进入Follower状态，等待新Leader的唤醒


其出现是为了 
* **解决单线程接受请求线程池线程处理请求下线程上下文切换**
* **线程间通信数据拷贝的开销**
* **不需要维护一个队列**

-----

DelayQueue的offer()方法如下所示：
```java
public boolean offer(E e) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        // 调用PriorityQueue.offer()
        q.offer(e);
        // 判断如果队首元素为新进入的元素
        if (q.peek() == e) {
            // 设置leader为null
            leader = null;
            // 唤醒其他线程
            available.signal();
        }
        return true;
    } finally {
        lock.unlock();
    }
}
```
Q1. 为什么要额外判断下`peek() == e`？
因为当一个线程进入leader状态时，仍会释放锁进入一段睡眠。那么此时如果新添加的offer优先度很高，就可以唤醒其他线程准备竞争任务。

------

DelayQueue的take()方法流程图如下所示：
![take方法流程图](https://blog-1252749790.file.myqcloud.com/collections/DelayQueue_take.png)

这里的逻辑简单来看就是如下所示：
![take方法白话文流程图](https://blog-1252749790.file.myqcloud.com/collections/DelayQueue_take2.png)


Q1. 为什么要特意设置 `first = null`
当消费者数量大于生产者，那么会有多个消费者线程持有队首元素的引用，然后在竞争锁的过程中，个别消费者长时间处于等待状态，那么GC发生时，队首元素就不会被回收（因为还是可达的），就发生了内存泄露。

Q2. 为什么要特意设置leader？根据Leader-Follower模式，似乎ReentrantLock已经能够满足只有一个线程在处理且其他线程进入等待
因为即使线程拿到了Lock锁，但是其中的await()也会释放锁进入等待状态。那么其他线程拿到锁后该如何知道是否有线程正在等待呢？那么就是靠这个leader变量。

Q3. 为什么设置了leader最后还要设置回null？
因为leader-follower，处理完后重新进入Follower状态

----
总结
DelayQueue涉及到了Leader-Follower模型，该模型的优势在于 **线程上下文开销**  相比  **单线程接受任务再交给多线程处理来说** 更低。
该类可以理解为代理类，它覆写的那些方法实际上调用的都是PriorityQueue的API。DelayQueue是线程安全的，PriorityQueue是线程不安全的。
要谨记await()方法会释放锁并进入等待