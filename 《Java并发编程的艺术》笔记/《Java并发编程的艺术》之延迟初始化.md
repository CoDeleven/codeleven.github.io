---
title: 《Java并发编程的艺术》之延迟初始化
date: 2018-05-06 10:18:58
tags: [Java并发, JMM]
---

在Java里，有时候需要延迟初始化来降低初始化类和创建对象的开销。为众人所致的双重检查锁定是常见的延迟初始化技术，但它是一个错误的用法。
比如下面的用法：
```java
public class UnsafeLazyInitialization{
    private static Instance instance;
    public static Instance getInstance(){
        if(instance == null){
            instance = new Instance();    
        }
        return instance;
    }
}
```
假设线程A执行getInstance()初始化对象还未完成时，线程B 判断 *instance* 变量为 null，也执行一遍Instance的初始化。那么最终会出现两个Instance变量。


当然，我们可以简单粗暴的给它加上 *synchronized*，保证同一时间只有一个线程能获得锁。
```java
public class SafeLazyInitialization{
    private static Instance instance;
    public synchronized static Instance getInstance(){
        if(instance == null){
            instance = new Instance();    
        }
        return instance;
    }
}
```
由于对getInstance() 方法做了同步处理，*synchrnoized* 将导致 *getInstance()* 方法被多个线程频繁的调用，将会导致程序执行性能的下降。

在早期，*synchronized* 存在巨大开销，人们为了降低互斥的开销，采取了一些技巧：“双重检查锁定”，通过“双重检查锁定”来降低同步的开销。下面时“双重检查锁定”的代码
```java
public class DoubleCheckLocking{
    private static Instance instance;
    public static Instance getInstance(){
        if(instance == null){
            synchronized(DoubleCheckLocking.class){
                instance = new Instance();
            }
        }
        return instance;
    }
}
```
如上面代码所示，如果第一次检查instance部位null，那么就不需要执行下面的加锁和初始化操作。因此可以大幅降低*synchronized*的开销。上面的代码完善了前面两个例子的缺点：
* 多个线程试图在同一个线程间创建对象；通过加锁保证只有一个线程能创建对象
* 在对象创建好后，再次访问*getInstance()* 不需要再获取锁，直接返回已经创建好的对象

然而“双重检查锁定”也存在问题，```instance = new Instance()``` 这句话可以拆成如下三行伪代码：

* memory = allocate(); // 分配对象的存储空间
* ctorInstance(memory); // 调用对象的初始化函数
* instance = memory; // 将instance指向 刚刚分配的内存地址

因为三行伪代码都再临界区内，所以编译器和处理器会对他做一些重排序，下面是可能的执行顺序：

* memory = allocate();
* instance = memory;
* ctorInstance(memory);

不违反happens-before的原则，所以JMM允许重排序，该代码在单线程可以运行的很高校，但是在多线程下会引发问题，即B线程会读取一个尚未完全初始化的对象。执行顺序流程图如下所示：

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/problem_doublechecklocking.png)


为了解决这个问题可以从两个方面下手：
1. 禁止图上2和5操作的重排序
2. 在初始化时，不允许其他线程访问

第一个方面可以通过volatile来实现，即
```java
public class NewDoubleCheckLocking{
    private volatile static Instance instance;
    public static Instance getInstance(){
        if(instance == null){
            synchronized(NewDoubleCheckLocking.class){
                instance = new Instance();
            }
        }
        return instance;
    }
}
```
前面讲过volatile关键字可以保证可见性和单个操作的原子性，所以可以避免创建对象过程被重排序。


第二个方面可以通过类初始化的解决
```java
public class InstanceFactory{
    public static class InstanceHolder{
        public static Instance instance = new Instance();
    }
    public static Instance getInstance(){
        return InstanceHolder.instance;
    }
}
```
假设线程A初次调用getInstance，线程B也初次调用，下面是执行的示意图。
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_conflict.png)

这里的语义和获取互斥锁一样，虽然允许初始化时的重排序，但是不会被其他线程所观测到。Java语言规范规定，对于每一个类或接口C，都有一个唯一的初始化锁LC与之对应。从C到LC的映射，由JVM的具体实现去自由实现。JVM在类初始化期间会获取这个初始化锁，并且每个线程至少获取一次锁来确保这个类已经被初始化过了。

第一个阶段：
线程A和线程B同时去获取Class的锁，线程A抢占成功并设置Class状态，随后就释放了锁；而线程B因此进入阻塞状态，示意图如下。
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_phase1.png)

第二个阶段：
线程A在释放了锁后就要开始初始化，而线程B获取到了锁，看到Class状态还是initializing，就放弃锁并进入等待状态。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_phase2.png)

第三个阶段
线程A执行完初始化，获取Class锁，将state设置为initialized，然后唤醒其他等待中的线程。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_phase3.png)

第四个阶段
线程B被唤醒，线程B尝试获取Class锁，读取到state为initialized，释放锁并访问这个类。

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_phase4.png)

第五个阶段
当初始化完毕后，线程C来访问该Class，线程C获取初始化锁，读取状态，如果为initialized就释放锁，直接访问类

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/init_phase5.png)