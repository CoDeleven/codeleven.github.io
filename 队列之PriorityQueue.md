---
title: 队列之PriorityQueue
date: 2018-05-17 09:58:51
tags: [Java集合]
---

由于该优先级队列是实现定时等任务的基础，所以想彻底理解后续的DelayQueue及ScheduledThreadPoolExecutor就要先学习优先级队列。

该队列是更具堆排序的划分优先级的队列，默认情况下优先级是使用按照自然顺序排序的比较器（即从小到大），当然你也可以传入一个比较器，让队列按照比较器排序。因为会用到比较器，所以每个元素都需要实现Comparable接口。

**注意：该队列不是线程安全的**

PriorityQueue有以下几个构造方法：

* PriorityQueue(): 创建一个可以存放11个元素的，**因为没有比较器，传入的元素必须要实现Comparable(像int、double这类可以自动装箱的元素不必实现，它们在强转的时候不会出问题)**。
* PriorityQueue(Collection<? extends E>): 根据给定的集合创建一个优先级队列，**每个元素都必须实现Comparable** 
* PriorityQueue(PriorityQueue<? extends E> c)
* PriorityQueue(SortedSet<? extends E> c) 
* PriorityQueue(int initialCapacity): 根据给定的初始容器大小，创建一个按自然数排序的优先级队列
* PriorityQueue(int initialCapacity, Comparator<? super E> comparator): 根据给定的初始容器大小和比较器，创建一个优先级队列，优先级队列会按照比较器进行排序
* PriorityQueue(Comparator<? super E> comparator): 该方法从1.8之后才有

## 属性介绍
| 变量名称   | 变量类型              | 作用                                     |
|------------|-----------------------|------------------------------------------|
| queue      | Object[]              | 二叉树。每一次插入或移除都会调整树的结构 |
| size       | int                   | 元素个数。                               |
| comparator | Comparator<? super E> | 比较器。决定队列是从小到大还是从大到小   |
| modCount   | int                   | 修改次数。每次增删操作都会使modCount递增 |

## offer()
在执行offer()方法前的队列状态，此时 **元素个数size**为7, **queue.length**为8

![插入前的初始状态](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_status0.png)

```java
public boolean offer(E e) {
    if (e == null)
        throw new NullPointerException();
    modCount++;
    int i = size;
    // 如果队列包含元素的数量大于等于数组的长度
    if (i >= queue.length)
        // 扩充数组长度
        grow(i + 1);
    // 递增总元素数量
    size = i + 1;
    if (i == 0)
        queue[0] = e;
    else
        // 关键点
        siftUp(i, e);
    return true;
}
```
执行offer()时，```i < queue.length``` 所以不扩容，只是对size进行递增。此时， **元素个数size为8**, **queue.length**为8。状态图如下所示

![插入时的状态1](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_status1.png)

offer()方法前面都在做一些准备，比如检查元素是否为null、检查数组长度。真正执行插入的地方在siftUp()。siftUp()就是将插入的元素调整到大于等于其祖先元素，说的术语点就是堆排序。这里会判断是否存在比较器，如果创建PriorityQueue没有传入Comparator时，则进入else，通过元素的Comparable判断；否则进入if语句
```java
private void siftUp(int k, E x) {
    if (comparator != null)
        siftUpUsingComparator(k, x);
    else
        siftUpComparable(k, x);
}
```
假设我们没传Comparator，进入else语句:
```java
private void siftUpComparable(int k, E x) {
    // 必须要让元素显式实现Comparable，如果是int、double这类可以自动装箱的元素，倒是不需要显式实现
    Comparable<? super E> key = (Comparable<? super E>) x;
    while (k > 0) {
        int parent = (k - 1) >>> 1;
        Object e = queue[parent];
        if (key.compareTo((E) e) >= 0)
            break;
        queue[k] = e;
        k = parent;
    }
    queue[k] = key;
}
```
k为新元素的下标，x为新元素的值。由于新元素尚未插入，其中的元素个数实际上还是只有k - 1个，故要执行```k - 1```。

1. (k - 1) / 2 获取 **祖先元素下标 parent** ，parent是**新元素 x** 的祖先元素的下标。
2. 将祖先（该新元素的parent）和新元素进行比较
3. 如果新元素和parent比较后返回0或负数，就将**新元素所在位置**设置为parent值；反之就直接插入（这里还是要具体看比较器，通常是小到大的排序，下文也是这样）
4. 最后将**新元素的下标 k**改成**parent所在位置 parent**，即新元素值要保存在parent所在位置
5. 继续拿**新元素下标 k** 比较，重复1-3的步骤

对不明白为什么要这么做的同学，请移步这里[排序算法之堆排序]()

当`siftUpComarable`执行完后，状态图如下所示（没有体现排序的过程）
![](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_status2.png)


## poll()
![poll前的初始状态](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_poll_status1.png)

```java
public E poll() {
    if (size == 0)
        return null;
    int s = --size;
    modCount++;
    E result = (E) queue[0];
    E x = (E) queue[s];
    queue[s] = null;
    if (s != 0)
        siftDown(0, x);
    return result;
}
```

poll()方法和offer()有异曲同工之妙，其区别主要在于它出队后，是通过将最后一个元素放在首结点，然后 **下沉** 调整堆结构的。

![将最后一个结点移到顶点](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_poll_status2.png)

```java
private void siftDownComparable(int k, E x) {
    Comparable<? super E> key = (Comparable<? super E>)x;
    int half = size >>> 1;        // loop while a non-leaf
    while (k < half) {
        int child = (k << 1) + 1; // assume left child is least
        Object c = queue[child];
        int right = child + 1;
        if (right < size &&
            ((Comparable<? super E>) c).compareTo((E) queue[right]) > 0)
            c = queue[child = right];
        if (key.compareTo((E) c) <= 0)
            break;
        queue[k] = c;
        k = child;
    }
    queue[k] = key;
}
```
`(k << 1) + 1` 获取到首结点的左子结点，`child + 1` 获取到右子结点。当`k < half`时，`(k >>> 1) + 1 <= size - 1`，所以只需要判断`right < size` 即可知道数组是否越界。此时状态图如下所示

![](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_poll_status3.png)


比较左子结点和右子节点，如果左大于右，将右下标设置给左下标，右值设置给左变量c

**注意：这里只将右结点的下标设置到左结点的下标，数组里的值还没有动，然后将c设置为right的值，并没有修改数组**

状态图如下所示
![](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_poll_status4.png)

此时比较新值x 和 变量c(即`min(leftValue, rightValue)`)，如果新值x最小，直接退出循环。反之，`queue[k] = c; k = child`

![](https://blog-1252749790.file.myqcloud.com/collections/PriorityQueue_poll_status5.png)

到这一步，前三个结点已经挑出最大值，看图可以得知数值“111”还没有设置进去，这是为什么呢？因为如果下标为2的结点还有子结点，还要和他们比较，最终才能确定一个最合适的位置。

当数值“111”确定下了位置`queue[k] = key;`将111设置到k的位置。

## 总结
到这一步，PriorityQueue的难点基本上没有了。让人头大的堆排序还是要归结于数据结构学的不够精，不过话说回来这段代码写的很妙，和看AQS一样的感觉，很精细，每个局部变量最大程度上被利用起来，缺一不可。