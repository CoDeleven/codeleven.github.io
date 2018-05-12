---
title: 《Java并发编程的艺术》之阻塞队列
date: 2018-05-12 09:48:01
tags: [Java并发]
---

阻塞队列是一个支持两个附加操作的队列。这两个附加的操作支持阻塞的插入和移除方法：

1) 支持阻塞的插入方法：当队列满时，队列会阻塞执行插入的线程
2) 支持阻塞的移除方法：当队列空时，队列会阻塞执行移除的线程

方法总结：

| 方法/处理方式 | 抛出异常  | 返回特殊值 | 一直阻塞 | 超时退出             |
|---------------|-----------|------------|----------|----------------------|
| 插入方法      | add(e)    | offer(e)   | put(e)   | offer(e, time, unit) |
| 移除方法      | 无  | poll()     | take()   | poll(time, unit)     |
| 检测方法      | element() | peek()     | 无       | 无                   |

* 抛出异常：当队列满时，插入元素会抛出```IllegalStateException```；
* 返回特殊值：offer()是入队方法，当插入成功时返回true，插入失败返回false；poll()是出队方法，当出队成功时返回元素的值，队列为空时返回null
* 一直阻塞：当队列满时，阻塞执行插入方法的线程；当队列空时，阻塞执行出队方法的线程
* 超时退出：顾名思义

在JDK7里，Java的阻塞队列总共有七个，每个类都继承```AbstractQueue```：

* ArrayBlockingQueue
* LinkedTransferQueue
* SynchronousQueue
* DelayQueue
* LinkedBlockingDeque
* LinkedBlockingQueue
* PriorityBlockingQueue

## ArrayBlockingQueue
该类是通过数组实现的有界阻塞队列，此队列按照FIFO的原则对元素进行排列。默认情况下不保证线程公平的访问队列，所谓公平访问是指阻塞的线程，可以按照阻塞的先后顺序访问队列，即先阻塞的先访问。公平访问是由ReentrantLock的公平锁实现的：
```java
public ArrayBlockingQueue(int capacity, boolean fair) {
    if (capacity <= 0)
        throw new IllegalArgumentException();
    this.items = new Object[capacity];
    lock = new ReentrantLock(fair);
    notEmpty = lock.newCondition();
    notFull =  lock.newCondition();
}
```
1. 因为直接创建的数组，ArrayBlockingQueue的长度无法更改，
2. 当ReentrantLock设置为公平锁后，后续所有Lock竞争中都会是公平竞争，没看过Condition原理的小伙伴会想，那和Condition有什么关系呢？答案是Condition在被唤醒时也要参与竞争Lock，那么在Lock竞争中都会遵守公平竞争。

## LinkedBlockingQueue
该类是一个用链表实现的有界阻塞队列（也不算有界，只是因为计数器最多只能计Integer.MAX_VALUE)。此队列的默认和最大长度为Integer.MAX_VALUE。按照先进先出的原则对元素进行排列。

## PriorityBlockingQueue
该类是一个支持优先级的无界阻塞队列。默认情况下元素采取自然升序的排序方式。也可以自定义类实现compareTo()来指定元素排序规则，或者初始化时指定Comparator来对元素排序。
详见：[坑还没填，迟点填]()

## DelayQueue
支持延时获取元素的无界阻塞队列。队列使用```PriorityQueue```来实现，队列中的元素必须实现Delayed接口，再创建元素时可以指定多久才能从队列中获取当前原色，只有在延迟期满时才能从队列中提取元素。
运用场景：
* 缓存系统的设计：可以用DelayQueue保存缓存元素的有效期，使用一个线程循环查询DelayQueue，一旦能从DelayQueue中获取元素，表示缓存有效期到了
* 定时任务调度：使用DelayQueue保存当天将会执行的任务和执行时间，一旦从DelayQueue中获取到任务就开始执行，比如TimerQueue

执行流程如下所示：

 首先实现```Delayed```接口：
 ```java
 @Override
 public long getDelay(TimeUnit unit){
     // 返回当前元素还需要等待多久，当返回<0的值时，表示可以出队；>0时，表示仍需要等待
 }
 ```

第二步，每次offer()时，往```PriorityQueue```插入元素会自行排序，按照自然升序排序

第三步，每次获取时(调用take()，才能有阻塞的功能)，如果时间未满会先阻塞
```java
for (;;) {
    E first = q.peek();
    if (first == null)
        available.await();
    else {
        long delay = first.getDelay(NANOSECONDS);
        if (delay <= 0)
            return q.poll();
        first = null; // don't retain ref while waiting
        if (leader != null)
            available.await();
        else {
            Thread thisThread = Thread.currentThread();
            leader = thisThread;
            try {
                available.awaitNanos(delay);
            } finally {
                if (leader == thisThread)
                    leader = null;
            }
        }
    }
}
```
具体的可以看： [了解之DelayQueue]()

## SynchronousQueue
一个不存储元素的队列，生产者生产一个，消费者消费一个，每一个put操作都需要等待一个take操作。该队列主要负责生产者线程处理的数据传递给消费者线程。比较适合传递性场景。其吞吐量高于ArrayBlockingQueue和LinkedBlockingQueue

## LinkedTransferQueue
该类主要添加了两个方法：```transfer()```和```tryTransfer()```
```transfer()``` 主要是当消费者线程在等待的时候，生产者一产生元素，就立刻交给消费者，不需要再进行额外的入队操作；如果没有消费者在等待，就先进入队尾。
```tryTransfer()``` 用来试探生产者传入的元素是否能直接传给消费者。

具体的可以看：[了解之LinkedTansferQueue]()


## 总结

* ArrayBlockingQueue
* LinkedBlockingQueue
* LinkedBlockingDeque
* SynchronousQueue
上面四个是较为简单的，数据结构和各个方法都较为简单就不一一阐述了。剩下三个则是比较大头的，而且比较新颖，打算单独拎出来讲解

该章主要是粗略的了解一下其他阻塞队列的功能，对于一些不常见的类，后续会补上详细的分析（其实是先补充一波数据结构和算法）