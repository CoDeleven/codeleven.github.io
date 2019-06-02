---
title: 《Java并发编程的艺术》之线程池(二)
date: 2018-05-14 10:50:19
tags: [Java并发]
---
# 线程池核心Executor
Java的线程既是工作单元，也是执行机制。从JDK5开始，把工作单元与执行机制分离开来。工作单元包括Runnable、Callable，而执行机制由Executor提供。

## Executor框架结构和流程
主要由以下三部分组成：
* 任务：Runnable、Callable接口
* 任务的执行：Executor，以及继承Executor的ExecutorService
* 异步计算的结果：Future接口、实现Future接口的FutureTask类

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/executor_member_flow.png)

各个部分的执行流程：

* 主线程创建任务（实现Runnable或Callable接口的任务对象）。工具类Executors可以把一个Runnable对象封装成Callable对象。
* 把Runnable对象直接交给ExecutorSerivce执行，或者也可以把Runnable对象或Callable对象提交给ExecutorService执行。
* submit()会返回一个实现Future接口的对象。主线程可以执行FutureTask.get()方法来等待任务执行完成。主线程也可以通过FutureTask.cancel()方法取消任务执行。

## Executor框架成员
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/executor_uml.jpg)

Executors可以创建以下四个ThreadPoolExecutor特殊应用的类：
* ThreadPoolExecutor
* FixedThreadPool，固定线程数量的线程池，多余的任务会加入无界的阻塞队列中
* SingleThreadPool，只有单个线程的线程池，多余的任务会加入无界的阻塞队列中
* CachedThreadPool，没有上限的线程池，使用的SynchronousQueue队列

Executors可以创建以下两个ScheduledThreadPoolExecutor特殊应用的类：
* ScheduledThreadPoolExecutor
* SingleThreadScheduledExecutor

下面将对Executor的后两个部分进行分解讲解

## ThreadPoolExecutor下的特殊应用（任务执行 部分）

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

### ScheduledThreadPoolExecutor
ScheduledThreadPoolExecutor虽然不是对ThreadPoolExecutor的参数进行调整，但是对其执行流程进行了一个调整。该类主要用来在给定的延时之后执行任务或定期执行任务。ScheduledThreadPoolExecutor和Timer类似，但是更强大。Timer在单线程下执行，如果前一个任务执行时间过长，会影响下一个任务的执行。

```java
public ScheduledThreadPoolExecutor(int corePoolSize,
                                   ThreadFactory threadFactory,
                                   RejectedExecutionHandler handler) {
    // 继承ThreadPoolExecutor
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue(), threadFactory, handler);
}
```
因为是无界队列，所以maximumPoolSize，aliveKeepTime和workQueue三个参数没什么意义（根据流程判断用不到它们）

ScheduledThreadPoolExecutor的执行主要分成两个部分：
* 当调用ScheduledThreadPoolExecutor的scheduleAtFixedRate()方法或者scheduleWithFixedDelay()方法时，会向DelayQueue添加一个实现了RunnableScheduledFuture接口的ScheduledFutureTask
* 线程池会从DelayQueue中获取ScheduledFutureTask，然后执行任务

ScheduledThreadPoolExecutor在ThreadPoolExecutor的基础上做了以下修改：

* 使用DelayQueue作为任务队列
* 获取任务的方式不同
* 执行任务时会做一些修改

接下来就围绕着上面三点不同点，研究ScheduledThreadPoolExecutor

#### DelayQueue作为任务队列
具体的内容看这篇

DelayQueue封装了一个PriorityQueue，这个PriorityQueue会对队列中的ScheduledFutureTask进行排序。time小的排在前面（时间早的任务先被执行）。如果两个task的taim相同就比较sequenceNumber，sequenceNumber小的排在前面。

#### 获取任务的方式
线程池总从DelayQueue中获取流程：
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/ScheduledThreadPool_flow.png)

1. 线程1从DelayQueue中获取已到期的ScheduledFutureTask
2. 线程1执行该task
3. 线程1修改该task的time变量为下一次执行的时间
4. 线程1把这个修改time后的task放回DelayQueue中

## FutureTask（异步结果 部分）
该类除了Future接口外还实现了Runnable接口。因此可以将FutureTask提交给线程池使用。该任务如果有多个线程尝试去执行，最终只会有一个线程可以执行，其他线程只能等待该任务执行完毕才能继续执行。

FutureTask可以处于以下三种状态：
* 未启动。在run()方法还没执行之前，FutureTask处于未启动状态
* 已启动。在run()方法执行过程中，FutureTask处于已启动状态
* 已完成。在run()方法执行完后正常结束、被取消、抛出异常。

![状态迁移示例图](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/FutureTask_state_change.png)
当FutureTask处于未启动或已启动状态，调用get()方法，会让调用线程进入阻塞状态；当FutureTask处于已完成状态，阻塞的get()方法会立即返回


![执行示意图](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/FutureTask_perform_flow.png)
不同状态下调用get/cancel方法，会有不同的影响


# 总结
无论是ScheduledThreadPoolExecutor还是FixedThreadExecutor等，都是ThreadPoolExecutor的特殊用法，只要把ThreadPoolExecutor搞懂，那么就不需要担心其他的特殊应用。