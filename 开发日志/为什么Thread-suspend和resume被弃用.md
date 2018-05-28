---
title: 为什么Thread.suspend和resume被弃用
date: 2018-04-04 09:13:24
tags: Java并发
---

笔者在学习JUC包的时候，了解到同样用于线程阻塞和恢复功能的类—— *LockSupport*，那么这个类和*Thread.suspend()* 和 *Thread.resume()* 有什么区别，为什么后者被弃用了？

## 阻塞小例子
该例子(来源于Bug Database)很好的验证了*Thread.suspend()/resume()*这对兄弟天生容易犯错，在输出几个i之后就会发生永久性阻塞（通过jstack看，只能判断其是阻塞，无法判断是死锁）。
```java
/* ---------Thread.suspend 和 resume发生“死锁”的示例--------- */
    public static void main(String[] args) throws InterruptedException {
        TestTask mainThread = new TestTask();
        mainThread.start();
        while(true){
            if(!mainThread.isTalking){
                // LockSupport.unpark(mainThread);
                mainThread.resume();
                mainThread.isTalking = true;
            }
        }
    }

    static class TestTask extends Thread {
        volatile boolean isTalking = true;
        int i = 0;

        public void run() {
            while (true) {
                if (isTalking) {
                    i++;
                    isTalking = false;
                    // LockSupport.park();
                    suspend();
                    System.out.println(i);
                }
            }
        }
    }
```

## 弃用原因
在这个方面，笔者上网了解过很多，许多人都是泛泛而谈，甚至是随手复制粘贴，质量低的可怕，完全无法了解到为什么它被弃用了。笔者最后在Bug Database上了解到了原因：
1. *Thread.suspend()和Thread.resume()* 发生阻塞的原因主要在于**底层JVM在暂停时候的不安全**
2. 就算花大力气修复了*Thread.suspend()和Thread.resume()*,问题也会转移到应用层级别（这一点暂时无法理解） 。

[*Thread.suspend()* 和 *Thread.resume()* 被弃用的原因](https://bugs.java.com/bugdatabase/view_bug.do?bug_id=4040218#)

有能力的朋友们可以直接看原文，可以一起交流一下看法。

## 替代方案
1. *Object.wait()*和*Object.notify()/notifyAll()*，该方法需要在*synchronized()*中使用，极其麻烦
2. *LockSupport* 粒度小，使用方便

## 小栗子
~~暂时没想法，后续补上~~