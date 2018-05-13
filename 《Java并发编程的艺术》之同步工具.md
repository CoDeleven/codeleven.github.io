---
title: 《Java并发编程的艺术》之同步工具
date: 2018-05-13 10:25:39
tags: [Java并发]
---

## CountDownLatch
该类主要实现了：让一个线程等待其他线程完成后再执行的功能，好比```Thread.join()```。

该类的初始化需要一个整数值count，当每次调用```CountDownLatch.countDown()```时Count会递减。直到count降到0时，所有执行```CountDownLatch.await()```的方法都会返回。

初始化了一个共享变量latch，并赋予count为3
```java
CountDownLatch latch = new CountDownLatch(3);
```

创建一个任务，睡眠1秒假装执行任务，最后执行countDown
```java
@Override
public void run() throw InterruptedException{
    System.out.println("执行任务...");
    Thread.sleep(1000);
    latch.countDown();
}
```

主线程里执行如下方法
```java
// 调用3个线程执行上述的任务
...
latch.await();
System.out.println("执行结束")
```

当三个任务线程全部执行完latch.countDown()时，main线程就会从阻塞的await()中返回，最后输出"执行结束"。
注意：CountDownLatch 只能使用一次，下一次使用要重新创建一个。

## CylicBarrier
该类和CountDownLatch有点类似，不过从名字就可以看出它是一个**可循环使用** 的类。它的功能主要是等待所有线程达到某个位置，然后统一执行。可以想象成出发旅游，大家都先到集合地等待，待所有人都到了，就可以出发了。

创建一个屏障
```java
CyclicBarrier barrier = new CyclicBarrier(4);
```

任务类，让先完成的任务进行等待，等待其他线程到达
```java
@Override
public void run() throw InterruptedException{
    System.out.println(Thread.currentThread.getName() + " -> 到达集合点");
    barrier.await();
    System.out.println(Thread.currentThread.getName() + "出发！")
}
```

睡5秒，不让主线程过早结束
```java
// 创建4个线程执行上述的任务
...
Thread.sleep(5000);
System.out.println("执行结束")
```

注意，如果barrier在等待过程中某个线程被中断了一次，那么整个barrier就需要重新来过。
```java
Thread thread = new Thread(() -> {
    try {
        barrier.await();
    } catch (InterruptedException e) {
        e.printStackTrace();
    } catch (BrokenBarrierException e) {
        e.printStackTrace();
    }
});
thread.start();
thread.interrupt();
try{
    barrier.await();
}catch (Exception e){
    System.out.println("无法等待...");
}
```

当另起的线程被中断后，后续的barrier就无法使用了，会抛出```BrokenBarrierException```

## Semaphore
该类被称作信号量，用于控制同一时间的线程执行数。想象下面一副场景:
```
-----------------
🚌     🚌 🚌 🚌↘---------------
🚌   🚌   🚌    🚌🚌  🚌🚌
   🚌    🚌  🚌↗---------------
-----------------
```

在窄路口里每次只能通过5辆车，5辆车通过后，后5辆车才能通过。Semaphore的作用就和它很类似，当有20条线程在执行IO密集型的任务，执行完后需要将处理结果存储到数据库中。如果数据库连接只有10条，那就要用semaphore去控制拿到数据库连接的线程数量。

Semaphore里没用过的方法：
* hasQueuedThreads()：是否有等待的线程
* getQueueLength()：返回正在等待获取许可证的线程数量

## Exchanger
该类是一个用于线程间协作的工具类。Exchanger用于进行线程间的数据交换。它提供一个同步点，在这个通不见，两个线程可以交换彼此间的数据。这两个线程通过exchange方法交换数据：如果第一个线程执行exchange()，它会一直等待第二个线程exchange()，当两个线程达到同步点，这两个线程就可以交换线程。
虽然我不知道这个类有啥作用(ε=ε=ε=┏(゜ロ゜;)┛
但是书上说可以用于遗传算法、校对工作：

```java
Exchanger<String> exchanger = new Exchanger<>();

new Thread(() -> {
    String dataOfAThread = Thread.currentThread().getName() + "-----A的数据";
    try {
        String resultOfBThread = exchanger.exchange(dataOfAThread);
        System.out.println(Thread.currentThread().getName() + "-------> " + resultOfBThread);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}).start();

new Thread(() -> {
    String dataOfBThread = Thread.currentThread().getName() + "-----B的数据";
    try {
        String resultOfAThread = exchanger.exchange(dataOfBThread);
        System.out.println(Thread.currentThread().getName() + "-------> " + resultOfAThread);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}).start();
```

最后输出：

```
Thread-1-------> Thread-0-----A的数据
Thread-0-------> Thread-1-----B的数据
```

## 总结
重新熟悉一下同步工具，学习到了CyclicBarrier被中断一次后，整个作废的点；学习到了Exchanger的适用场景