---
title: 深入Unsafe
date: 2018-04-05 19:56:34
tags: Java并发
---

在JUC（并发包）里经常会使用到`Unsafe`这个类，那么了解这个类，就成为了下面学习的重中之重

```java
/**
 * 注意如果是获取基础变量类型，那么所有方法都要调用对应基础变量类型的方法，不能使用Object代替全部，因为C语言底层是没有包装类型的
 */

/*------------------对象操作------------------*/

/**
 * 返回一个字段的偏移量
 * PS：注意区分objectFieldOffset和staticFieldOffset，一个操作的参数是对象实例，一个是Class对象
 * 不要对该偏移量进行任何处理，该偏移量会被传给不安全的堆内存里
 *
 * @param f Class文件里面的字段
 */
long objectFieldOffset(Field f);

/**
 * 获取变量时，具有volatile语义
 * PS:如果是获取静态变量，那么Object就要用Class；获取非静态变量，那么Object就要用对应的Object
 * 
 * @param o 待获取的对象，要区分Class和Object
 * @param offset 对象里某个位置的偏移量，@see #objectFieldOffset(Field)
 */
Object getObjectVolatile(Object o, long offset)

/**
 * 为Object实例设置一个值，具有volatile的语义
 *
 * @param o 目标实例
 * @param offset 对应字段的偏移量
 * @param x 要赋予的值
 */
void putObjectVolatile(Object o, long offset, Object x);

/**
 * 获取静态字段的偏移量
 * PS：注意区分objectFieldOffset和staticFieldOffset，一个操作的参数是对象实例，一个是Class对象
 * 不要对该偏移量进行任何处理，该偏移量会被传给不安全的堆内存里
 * 
 * @param f Class文件里的静态字段
 */
long staticFieldOffset(Field f);

/**
 * 延迟设置属性
 * 对于volatile属性来说是立即生效的。
 * 详情见putOrderedObject小节
 * 
 * @see #putObjectVolatile
 */
 void putOrderedObject(Object o, long offset, Object x);

/**
 * 非阻塞锁的属性交换
 * 比较字段的值和原来的是否一样，如果一样就进行设置
 * 
 * @param o 要操作的实例对象
 * @param offset 要操作的字段
 * @param expected 原来的值
 * @param x 新的值
 * @return 设置是否成功
 */
boolean compareAndSwapInt(Object o, long offset, int expected,
 int x);

/*------------------数组操作------------------*/

/**
 * 获取array第一个元素的偏移量
 * 该数值配合arrayIndexScale使用
 * 通过arrayBaseOffset + arrayIndexScale * index 获取对应下标的元素
 * arrayBaseOffset在64位下，都是16（没有开启指针压缩）
 * arrayIndexScale根据不同的类型，有不同的值，比如double是8，int是4
 * 
 * @param arrayClass 数组的Class的类型，比如A[].class
 */
int arrayBaseOffset(Class arrayClass);

/**
 * 获取数组元素的增量
 * 
 * @arrayClass 数组的Class类型
 */
int arrayIndexScale(Class arrayClass);

/*------------------锁相关操作------------------*/

/** 锁对象 */
void monitorEnter(Object o);

/** 解锁对象 */
void monitorExit(Object o);

/*------------------线程相关操作------------------*/

/** 
 * block当前线程
 * 在以下几种情况下会结束阻塞并返回
 * 1. 在park前调用unpark或者在park后调用unpark均可立即返回
 * 2. 当前线程被中断（interrupte）
 * 3. 阻塞时间超过给定值
 * 4. ？？没有任何原因的返回？？
 * @param isAbsolute true则使用Epoch来表示；false则使用相对时间
 * @param time 根据isAbsolute来决定，若为true，表示绝对时间（epoch、unix时间戳）单位毫秒；若为false，表示相对时间（相对现在多少纳秒以后返回），单位纳秒;若time为0，表示永远阻塞
 */
void park(boolean isAbsolute, long time);

/** 
 * unblock指定的线程
 * 当unblock不同状态的线程有不同的现象：
 * 当指定线程已经阻塞，那么unblock指定的线程
 * 当指定线程尚未阻塞，那么指定线程的下一次park将不会产生阻塞
 * 
 * @param thread  请确保thread不为空
 */
void unpark(Object thread);
```

## putOrderedObject整理
这方法纠结了我很久，因为doc上很简略，大体就是讲对**非volatile变量的修改**对其他线程不会立即生效

1. 那么这货有什么用？
2. 这货和普通写入有什么区别吗？（因为普通写入对其他线程也不会立即生效）

下面的Bug Report是为什么添加“lazySet”的初衷：

[Bug_6275329 By Doug Lea](https://bugs.java.com/bugdatabase/view_bug.do?bug_id=6275329)

>"As probably the last little JSR166 follow-up for Mustang,
we added a "lazySet" method to the Atomic classes
(AtomicInteger, AtomicReference, etc). This is a niche
method that is sometimes useful when fine-tuning code using
non-blocking data structures. The semantics are
that the write is guaranteed not to be re-ordered with any
previous write, but may be reordered with subsequent operations
(or equivalently, might not be visible to other threads) until
some other volatile write or synchronizing action occurs).

我们添加了“lazySet”一方法给AtomicX这些类（比如AtomicInteger、AtomicReference等）。这个方法在使用非阻塞数据结构调整代码的情况下很有用。它的作用主要表现在 **保证写入前的操作的不会被重排序，写入后的操作可能会被重排序（换言之就是写入后对其他线程不会立即可见）** 直到有其他的volatile写入或者同步操作发生。


>The main use case is for nulling out fields of nodes in
non-blocking data structures solely for the sake of avoiding
long-term garbage retention; it applies when it is harmless
if other threads see non-null values for a while, but you'd
like to ensure that structures are eventually GCable. In such
cases, you can get better performance by avoiding
the costs of the null volatile-write. There are a few
other use cases along these lines for non-reference-based
atomics as well, so the method is supported across all of the
AtomicX classes.

这个方法的主要用途是 在非阻塞数据结构中单独空出结点，来降低长时间的垃圾滞留问题来的性能问题；这能运用在就算其他线程看到非空值也没关系的情况下。但是你要确保这个结构确实能够被GC。在这种情况下，你能通过避免null值的写入，来获得更好的性能。

>For people who like to think of these operations in terms of
machine-level barriers on common multiprocessors, lazySet
provides a preceeding store-store barrier (which is either
a no-op or very cheap on current platforms), but no
store-load barrier (which is usually the expensive part
of a volatile-write)."

对于那些在通用多处理器下需要考虑底层机器屏障的人来说，“lazySet”提供了预Store-Store屏障（对于现在的平台来说，要么无操作，要么代价不大），但是没有Store-Load屏障（通常需要付出较高的代价）

PS：因为“lazySet”其实就是“volatile”的削弱版，所以叫“weak volatile”也挺符合的。

-----

### “weak volatile”的场景：
“weak volatile”适用于对实时性要求不高的场景，该方法可以较大的节省性能消耗

1. ~~一个链表中的某个节点被修改了，在volatile的情况下，整个链表都会一定被强制更新；而在"weak volatile"的情况下，不被强制更新，节省部分性能。~~
2. 在修改帖子状态的时，如果对性能要求很高，可以使用“lazySet”保证写入内存，但是对实时性的要求不高

具体的其他场景可以看下面的链接（表示第一个回答没看懂，功力深了后再来）
1. [AtomicXXX.lazySet(…) in terms of happens before edges ----StackOverflow](https://stackoverflow.com/questions/7557156/atomicxxx-lazyset-in-terms-of-happens-before-edges)

------

### “weak volatile”的原理
volatile的工作原理是插入屏障，在写入的时候插入StoreStore，写完后插入StoreLoad，根据Doug Lea的说法，StoreLoad相比StoreStore更消耗资源
而“weak volatile”则是省去了最后的StoreLoad的步骤，相比插入两个屏障，“weak volatile”性能提升了不少

更加具体的底层原理可以看下面的链接

1. [JUC中Atomic class之lazySet的一点疑惑----并发编程网](http://ifeve.com/juc-atomic-class-lazyset-que/)
