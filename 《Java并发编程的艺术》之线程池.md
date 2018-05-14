---
title: 《Java并发编程的艺术》之线程池
date: 2018-05-14 10:50:19
tags: [Java并发]
---

# 线程池
线程池的优点：

* 降低资源开销：每次任务到达时不需要重新创建和销毁
* 提高可管理性：统一对线程进行调优、监控
* 提高任务响应速度：不需要等待线程创建

线程池创建的各个参数：

* corePoolSize： 核心线程数。在核心线程数未满时，也优先创建满核心线程数（就算有空余的核心线程）
* maximumPoolSize： 最大线程数。当workQueue满的时候，创建新线程来执行新任务
* keepAliveTime：存活时间。非核心线程可空闲的最大时间
* workQueue: 任务阻塞队列。当提交新任务且核心线程数已经被使用完时，新任务会先加入任务队列

线程池中线程创建流程：
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/threadpool_create_flow.png)

1. 提交任务时，先判断核心线程数**是否已经创建完毕**，如果没有，则**先将核心线程数创建满**；反之则进入下个阶段
2. 判断核心线程数是否已经全部被占用，如果没有则交给核心线程执行；反之进入下个阶段
3. 判断工作队列是否已满，如果没满加入队列等待；反之进入下个阶段
4. 判断当前线程数是否小于MaxThread，如果是，则创建新线程执行任务；反之调用RejectPolicyHandler执行对应的策略


## 线程池的创建
我们可以通过ThreadPoolExecutor创建一个线程池
```java
ThreadPoolExecutor(
    int corePoolSize,
    int maximumPoolSize,
    long keepAliveTime,
    TimeUnit unit,
    BlockingQueue<Runnable> workQueue，
    RejectedExecutionHandler handler)
```

1) corePoolSize: 当提交一个任务时（即使其他空闲核心线程也能够执行新任务），线程池会创建一个新线程来执行任务，等到corePoolSize个线程被创建了，就不再创建了。如果要额外创建，就要看后面的参数。如果调用了线程的```prestartAllCoreThreads()``` 方法，线程池会提前创建并启动所有核心线程

2) maximumPoolSize: 线程池允许创建的最大线程数。如果队列满了，并且已经创建的线程数小于最大线程数，则线程池会再创建新的线程执行任务。如果使用了无界队列，该参数没什么效果

3) keepAliveTime: 线程池的工作线程空闲后，保持存活的时间。如果每个线程执行时间较短，可以将该值调大，提高线程利用率

4) unit: 时间单位

5) workQueue: 用于保存等待执行的任务的阻塞队列，可以选择以下几个阻塞队列：

    * ArrayBlockingQueue: 是一个基于数组结构的有界阻塞队列，此队列按FIFO原则队元素进行排序
    * LinkedBlockingQueue: 一个基于链表结构的阻塞，此队列按FIFO排序元素，吞吐量通常要高于ArrayBlockingQueue。静态工厂方法Executors.newFixedThreadPool()使用了这个队列。
    * SynchronousQueue: 一个不存储元素的队列。每个插入操作要必须等到另一个线程调用移除操作，否则插入操作一直处于阻塞状态，吞吐量通常要高于LinkedBlockingQueue，静态工厂方法Executors.newCachedThreadPool使用了这个队列
    * PriorityQueue: 一个具有优先级的无限阻塞队列

6) handler: RejectPolicy默认有四种：
    * AbortPolicy，直接抛出异常
    * DiscardPolicy，丢弃该任务，放弃处理
    * CallerRunsPolicy，只用调用者线程执行任务
    * DiscardOldestPolicy，丢弃队列里的队首元素

## 执行任务
线程池提交任务有两个方法向线程池提交任务，分别为execute()和submit():

* execute: 执行后没有返回值，无法判断任务是否被线程池执行成功
* submit: 提交后会返回一个Future类型的对象，通过该Future对象可以判断执行是否成功。其中get方法可以阻塞当前线程直到任务完成，get(timeout, unit)方法可以阻塞当前线程一段时间后返回

## 关闭线程
关闭线程池有两个方法，分别为```shutdown()``` 和 ```shutdownNow()```

共同点：
遍历线程池中的所有线程，然后逐个调用线程的```interrupt()```方法来中断线程，所以无法响应中断的线程可能永远无法被终止。

不同点：
* shutdownNow首先将线程池的状态设置为STOP状态，然后尝试停止所有的正在执行或暂停任务的线程，并返回等待执行任务的列表
* shutdown只是将线程池的状态设置成SHUTDOWN状态，然后中断所有没有正在执行任务的线程

当任意一个关闭方法被调用时，isShutdown()方法就会返回true。当所有的任务关闭后，调用isTerminated()才会返回true。

具体要调用```shutdown()```还是```shutdownNow()```，需要根据具体业务来判断(通常调用```shutdown()```)。如果任务不一定要执行完，可以用```shutdownNow()```

## 合理配置
* 任务的性质：CPU密集型任务、IO密集型任务、混合型任务
* 任务的优先级：高、中、低
* 任务的执行时间：长、中、短
* 任务的依赖性：是否依赖其他系统资源，如  数据库连接

如何挑选：
* CPU密集型任务需要长时间用到CPU运算，所以线程数量最好配置: N<sub>cpu + 1</sub> 
* IO密集型任务并不是一直占用CPU，则尽可能配置多的线程: 2 * N<sub>cpu</sub>
* 如果是混合型任务，尝试将其拆分为CPU密集型任务和IO密集型任务
* 依赖数据库连接池的任务，因为线程提交SQL后需要等待数据库返回结果，等待的时间越长，则CPU空闲时间越长，那么线程数应该设置的越大，这样才能更好的利用CPU。

注意：建议使用有界队列，因为如果线程池里的工作线程全部阻塞，任务挤压在线程池里，最终会导致整个系统不可用


## 监控要素
* taskCount: 线程池需要执行的任务数量
* completedTaskCount: 线程池在运行过程中已完成的任务数量，小于等于taskCount
* targetPoolSize: 线程池里曾将创建过的最大线程数。通过这个数据可以直到线程池是否曾经瞒过。
* getPoolSize: 线程池的线程数量。如果线程池不销毁，线程池里的线程不会自动销毁，所以该值只增不减
* getActiveCount: 获取活动的线程数

通过扩展线程池进行监控。可以通过继承线程池来自定义线程池，重写线程池的```beforeExecute()```, ```afterExecute()```, ```terminated()``` 方法，也可以在任务执行前、后执行一些代码来监控。

# 线程池核心Executor
Java的线程既是工作单元，也是执行机制。从JDK5开始，把工作单元与执行机制分离开来。工作单元包括Runnable、Callable，而执行机制由Executor提供。

## Executor框架结构和流程
主要由以下三部分组成：
* 任务：Runnable、Callable接口
* 任务的执行：Executor，以及继承Executor的ExecutorService
* 异步计算的结果：Future接口、实现Future接口的FutureTask类

![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/executor_member_flow.png)

各个部分的执行流程：

* 主线程创建任务（实现Runnable或Callable接口的任务对象）。工具类Executors可以把一个Runnable对象封装成Callable对象。
* 把Runnable对象直接交给ExecutorSerivce执行，或者也可以把Runnable对象或Callable对象提交给ExecutorService执行。
* submit()会返回一个实现Future接口的对象。主线程可以执行FutureTask.get()方法来等待任务执行完成。主线程也可以通过FutureTask.cancel()方法取消任务执行。

## Executor框架成员
![](https://blog-1252749790.file.myqcloud.com/JavaConcurrent/executor_uml.jpg)

Executors可以创建以下四个ThreadPoolExecutor特殊应用的类：
* ThreadPoolExecutor
* FixedThreadPool，固定线程数量的线程池，多余的任务会加入无界的阻塞队列中
* SingleThreadPool，只有单个线程的线程池，多余的任务会加入无界的阻塞队列中
* CachedThreadPool，

Executors可以创建以下两个ScheduledThreadPoolExecutor特殊应用的类：
* ScheduledThreadPoolExecutor
* SingleThreadScheduledExecutor

## ThreadPoolExecutor下的特殊应用

### FixedThreadPool
FixedThreadPool的创建方法，FixedThreadPool其实就是ThreadPoolExecutors的特殊用法：
```java
// 只能通过Executors.newFixedThreadPool()创建
public static ExecutorService newFixedThreadPool(int nThreads) {
    return new ThreadPoolExecutor(nThreads, nThreads,
                                  0L, TimeUnit.MILLISECONDS,
                                  new LinkedBlockingQueue<Runnable>());
}
```
主要需要注意的是```LinkedBlockingQueue```这个无界阻塞队列，该阻塞队列会造成以下几个影响：
* 执行中的线程数达到corePoolSize，新任务会在无界队列中等待，所以线程数不会超过corePoolSize
* 因为不会创建更多的线程，所以maximumPoolSize和keepAliveTime参数就没什么作用了
* 因为是无界队列，所以也不需要用到RejectPolicyHandler

### SingleThreadExecutor
该类也是ThreadPoolExecutor的特殊用法
```java
public static ExecutorService newSingleThreadExecutor() {
    return new FinalizableDelegatedExecutorService
        (new ThreadPoolExecutor(1, 1,
                                0L, TimeUnit.MILLISECONDS,
                                new LinkedBlockingQueue<Runnable>()));
}
```
相比FixedThreadPool，除一个正在执行任务的线程，其他任务都会一一加入队列中等待执行。

### CachedThreadPool
该类比较特殊，是FixedThreadPool的无限版本：
```java
public static ExecutorService newCachedThreadPool() {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>());
}
```
一手```SynchronousQueue```，保证每次offer任务时，需要一个线程poll该任务，否则```SynchronousQueue```会阻塞。所以其应用场景就是在任务量多，但是执行时间短的场景下。但是我认为这个方法有点无用，普通的线程池可以完全胜任该工作

## ScheduledThreadPoolExecutor
该类主要用来在给定的延时之后执行任务或定期执行任务。ScheduledThreadPoolExecutor和Timer类似，但是更强大。Timer在单线程下执行，如果前一个任务执行时间过长，会影响下一个任务的执行。

```java
public ScheduledThreadPoolExecutor(int corePoolSize,
                                   ThreadFactory threadFactory,
                                   RejectedExecutionHandler handler) {
    // 继承ThreadPoolExecutor
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue(), threadFactory, handler);
}
```
