---
title: ForkJoin并不是银弹
date: 2018-04-26 15:11:46
tags: [Java并发]
---

这是一段难受的排Bug的经历，ForkJoin框架的粗浅理解让我在单核服务器下发生了**栈溢出**，因为"ForkJoinPool.invokeAll()"的底层原理不仅会调用空闲的线程，也会调用当前的线程。如果处理不好，在单核服务器下就会发生死循环，最终产生栈溢出。
```java
Exception in thread "main" java.util.concurrent.ExecutionException: java.lang.St
ackOverflowError
        at java.util.concurrent.FutureTask.report(Unknown Source)
        at java.util.concurrent.FutureTask.get(Unknown Source)
        at cn.codeleven.App.main(App.java:20)
Caused by: java.lang.StackOverflowError
        at sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)

        at sun.reflect.NativeConstructorAccessorImpl.newInstance(Unknown Source)

        at sun.reflect.DelegatingConstructorAccessorImpl.newInstance(Unknown Sou
rce)
        at java.lang.reflect.Constructor.newInstance(Unknown Source)
        at java.util.concurrent.ForkJoinTask.getThrowableException(Unknown Sourc
e)
        at java.util.concurrent.ForkJoinTask.reportException(Unknown Source)
        at java.util.concurrent.ForkJoinTask.join(Unknown Source)
        at cn.codeleven.handler.XiCiHandler.handleDocument2IPEntity(XiCiHandler.
java:40)
        at cn.codeleven.Crawler.start(Crawler.java:34)
        at cn.codeleven.Crawler.run(Crawler.java:20)
        at java.util.concurrent.Executors$RunnableAdapter.call(Unknown Source)
        at java.util.concurrent.FutureTask.run(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.lang.Thread.run(Unknown Source)
Caused by: java.lang.StackOverflowError
        at java.util.stream.ReferencePipeline$3$1.<init>(Unknown Source)
        at java.util.stream.ReferencePipeline$3.opWrapSink(Unknown Source)
        at java.util.stream.AbstractPipeline.wrapSink(Unknown Source)
        at java.util.stream.AbstractPipeline.wrapAndCopyInto(Unknown Source)
        at java.util.stream.ReduceOps$ReduceOp.evaluateSequential(Unknown Source
)
        at java.util.stream.AbstractPipeline.evaluate(Unknown Source)
        at java.util.stream.ReferencePipeline.collect(Unknown Source)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:34)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:13)
        at java.util.concurrent.RecursiveTask.exec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doExec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doInvoke(Unknown Source)
        at java.util.concurrent.ForkJoinTask.invokeAll(Unknown Source)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:36)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:13)
        at java.util.concurrent.RecursiveTask.exec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doExec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doInvoke(Unknown Source)
        at java.util.concurrent.ForkJoinTask.invokeAll(Unknown Source)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:36)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:13)
        at java.util.concurrent.RecursiveTask.exec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doExec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doInvoke(Unknown Source)
        at java.util.concurrent.ForkJoinTask.invokeAll(Unknown Source)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:36)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:13)
        at java.util.concurrent.RecursiveTask.exec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doExec(Unknown Source)
        at java.util.concurrent.ForkJoinTask.doInvoke(Unknown Source)
        at java.util.concurrent.ForkJoinTask.invokeAll(Unknown Source)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:36)
        at cn.codeleven.handler.MyTask.compute(MyTask.java:13)
```