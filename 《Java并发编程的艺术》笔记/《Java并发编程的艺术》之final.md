---
title: 《Java并发编程的艺术》之final
date: 2018-05-03 10:52:35
tags: [Java并发, JMM]
---

## final的重排序规则
以下面的代码为例，讲解final写和final读的重排序规则
```java
public FinalExample{
    int a;
    final int b;
    private static FinalExample self;
    private FinalExample(){
        this.a = 1;
        this.b = 5;
    }
    
    public static FinalExample init(){ //线程A执行
        self = new FinalExample();
    }

    public static void read(){ //线程B执行
        FinalExample temp = self; // 获取引用
        int resultA = temp.a; // 读普通域
        int resultB = temp.b; // 读final域
    }
}
```

### final写的重排序规则
* JMM保证写final变量时不被编译器重排序到构造函数外
* 编译器会在写final域后，构造函数返回前插入StoreStore屏障

假设现在线程A执行init()，线程B执行read()时，可能的执行顺序如下所示：

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/final_write_sequence.png)

当A线程初始化构造函数的时候，有可能会将普通域的初始化重排序到构造函数外，所以当B线程读取普通域的时候很可能获取到0，但是在后续的执行中，该值又会变成给定的数值1。
而编译器在遇到final域时，会在final写后面加入StoreStore内存屏障，保证在结束函数构造前执行final写。

final域可以保证任何线程在读取该final变量时，已经正确初始化过。

### final读的重排序规则
在讲final写的重排序规则时，着重点放在了写上。而final域在读方面也做了一些特别处理。通常情况下，一个获取对象的引用和读取该对象的普通域是可能发生重排序。所以可能会发生下面这样的执行顺序：

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/final_read_sequence.png)

read()方法乍一看好像不会发生重排序，因为resultA 的写好像依赖temp变量。而resultA实际上是依赖temp引用里的a变量，**间接依赖temp对象**。虽然有的处理器不会对间接依赖进行重排序，但是不乏万一，比如alpha处理器，JMM就是为了避免这种会重排序**间接依赖**的处理器，所以给final读加上了下面的重排序规则：

* JMM保证 初次读对象引用与初次读该对象的final域不会被重排序
* 编译器会在读final域的前面插入LoadLoad屏障

## final域为引用类型
在构造函数内对一个final引用的对象的成员的写入，与随后在构造函数外把这个被构造对象的引用赋值给一个引用变量，这两个操作不能重排序。

## final引用不能从构造函数内“溢出”
写final的重排序规则虽然保证了，final域的写会在构造函数执行之前完成，并对其他线程可见。但是如果在构造函数内，引用就发生了溢出，那么就无法保证了
```java
public EscapeFinalExample{
    int a;
    final int b;
    private static EscapeFinalExample self;
    private EscapeFinalExample(){
        this.a = 1;
        this.b = 5;
        self = this; // this引用溢出
    }
    
    public static EscapeFinalExample init(){ //线程A执行
        new EscapeFinalExample();
    }

    public static void read(){ //线程B执行
        EscapeFinalExample temp = self; // 获取引用
        int resultA = temp.a; // 读普通域
        int resultB = temp.b; // 读final域
    }
}
```
假设线程A执行init()，线程B执行read()，这里的A线程还未完成完整的初始化方法，对象引用就被B可见了。即使代码上 this溢出操作放在最后，仍然有可能被重排序。它们的执行时序如下所示：

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/final_escape_sequence.png)

上图可以看出，构造函数还没有完成时，final域对其他线程不可见。只有在完成了构造函数后，final域才对其他线程可见。

## final语义的特殊例子
在X86处理器上，由于不会发生写写、读写、读读的重排序，所以没有StoreStore内存指令，故在使用final时，编译器会忽略StoreStore内存屏障，同样LoadLoad内存屏障也会被忽略。也就是说，在x86处理器上，final是不做任何处理的。

## 为什么要增强final语义呢
一方面是final本身是不可修改的，其他线程不该看到final的变化。比如一开始线程读取final值为默认值0，过一段时间再读这个final变量，final值变为值1（被初始化后）。
所以新的模型就保证了，只要正确的完成构造函数（不发生this溢出），即使不用同步，也可以保证其他线程见到final初始化后的值。