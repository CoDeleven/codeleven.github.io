---
title: 《Java并发编程的艺术》之final
date: 2018-05-10 13:29:46
tags: [Java并发]
---

HashMap只是相对线程安全，如果出现数据竞争就抛出fail-fast；HashTable则将每个操作都上锁，如果有耗时的操作，那么后续的操作均会被阻塞，大大降低程序的吞吐率。而ConcurrentHashMap正是为了解决这样一个问题而出现的。
ConcurrentHashMap和HashMap的数据结构如下所示：

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/HashMapDT.png)
![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/ConcurrentHashmapDT.png)

HashMap会持有一个Entry数组，每个Entry都是链表的结点，每次进行修改时，先查找key对应的hash值，找到BucktIndex，在遍历链表查看key是否相等。

ConcurrentHashMap会持有一个Segment数组，每个segment会持有一个HashEntry的数组，HashEntry又可以串成链表。每次进行写操作时，只需要加锁一个Segment即可，这就是**分段加锁技术**。相比HashMap，ConcurrentHashMap的修改就会比较费劲：首先要通过哈希key定位SegmentIndex，再对hash值进行再哈希获取BucketIndex，找到对应的Bucket，就可以进行和HashMap一样的操作，即遍历链表。

ConcurrentHashMap需要了解一些初始参数：
* segmentShift： segment的偏移量，有效的hash部分
* segmentSize： segment数组的长度
* concurrencyLevel： 并发等级，默认16，不会直接使用，而是通过这个值获取segment数组的长度和偏移量
* initCapacity： 初始化时容器的总大小，不会直接使用这个值，而是将其均分到不同的segment中
* loadFactor： 负载因子
* threshold： 阈值，Segment判断HashEntry数组(table)是否需要扩容的标准

这里摘抄了一段初始化的代码，省略了一些不必要的代码：
```java
public ConcurrentHashMap(int initialCapacity,
                         float loadFactor, int concurrencyLevel) {
    // 偏移量
    int sshift = 0;
    // segment数组的长度
    int ssize = 1;
    // 找到一个最适合的 二的N次方 的长度
    while (ssize < concurrencyLevel) {
        ++sshift;
        ssize <<= 1;
    }
    // segment偏移量，后面定位的时候需要用到
    this.segmentShift = 32 - sshift;
    // segment数组的长度
    this.segmentMask = ssize - 1;
    if (initialCapacity > MAXIMUM_CAPACITY)
        initialCapacity = MAXIMUM_CAPACITY;
    // 获取capacity的倍数
    int c = initialCapacity / ssize;
    // 保证持有的HashEntry大于等于initialCapacity
    if (c * ssize < initialCapacity)
        ++c;
    // MIN_SEGMENT_TABLE_CAPACITY 为 2
    int cap = MIN_SEGMENT_TABLE_CAPACITY;
    while (cap < c)
        cap <<= 1;
    // 创建segment数组和第一个segment
    Segment<K,V> s0 =
            new Segment<K,V>(loadFactor, (int)(cap * loadFactor),
                    (HashEntry<K,V>[])new HashEntry[cap]);
    Segment<K,V>[] ss = (Segment<K,V>[])new Segment[ssize];
}
```
先通过移位运算符，找到最小的大于concurrencyLevel的次数，对ssize进行移位、sshift进行递增。segmentShift为定位segment的便宜量，segmentMask为有效位数。ssize是segment数组的长度，通过```initialCapacity / ssize```均分可持有的HashEntry数组。最后创建segment，segment需要loadFactor，cap * loadFactor (threshold，判断HashEntry数组是否需要扩容的标准)，HashEntry数组。

通过这一系列初始化，多多少少能感觉到它和HashMap的相似之处。

## put操作
```java
// ConcurrentHashMap.put()
public V put(K key, V value) {
    Segment<K,V> s;
    if (value == null)
        throw new NullPointerException();
    // 对key进行hash
    int hash = hash(key);
    // 定位Segment的位置，原理和取余有些类似
    int j = (hash >>> segmentShift) & segmentMask;
    // 获取对应的Segment
    if ((s = (Segment<K,V>)UNSAFE.getObject(segments, (j << SSHIFT) + SBASE)) == null)
        // 创建新的segment
        s = ensureSegment(j);
    // 将键值对放入对应的segment里面
    return s.put(key, hash, value, false);
}
```
```java
// Segment.put()
final V put(K key, int hash, V value, boolean onlyIfAbsent) {
    // 先尝试加锁，加锁失败后进入scanAndLockForPut
    // scanAndLockForPut可以理解为是查找对应hash值的Entry
    // 如果没有就及时创建
    HashEntry<K,V> node = tryLock() ? null :
            scanAndLockForPut(key, hash, value);
    V oldValue;
    try {
        HashEntry<K,V>[] tab = table;
        // 根据hash值定位BucketIndex
        int index = (tab.length - 1) & hash;
        // 获取对应位置的Bucket
        HashEntry<K,V> first = entryAt(tab, index);
        for (HashEntry<K,V> e = first;;) {
            if (e != null) {
                // 该条件指 遍历链表
                K k;
                if ((k = e.key) == key ||
                        (e.hash == hash && key.equals(k))) {
                    oldValue = e.value;
                    if (!onlyIfAbsent) {
                        e.value = value;
                        ++modCount;
                    }
                    break;
                }
                e = e.next;
            }
            else {
                // 该条件指 对应位置的Bucket为空，需要创建这个位置的Bucket
                if (node != null)
                    // 不存在该hash值的entry，这里将其新创建的entry设置为first
                    node.setNext(first);
                else
                    // 不存在该hash值的entry，也没有新创建的entry，这里执行创建
                    node = new HashEntry<K,V>(hash, key, value, first);
                // Bucket数组的长度增加
                int c = count + 1;
                // 判断是否达到阈值
                if (c > threshold && tab.length < MAXIMUM_CAPACITY)
                    // 再hash,相当于扩容
                    rehash(node);
                else
                    // 将node设置到对应的bucketIndex上
                    setEntryAt(tab, index, node);
                ++modCount;
                count = c;
                oldValue = null;
                break;
            }
        }
    } finally {
        unlock();
    }
    return oldValue;
}
```
put操作虽然会对共享变量进行写入操作，但是执行前会获取到排斥锁，保证同一时刻只有一个线程能修改共享变量。

* ConcurrentHashMap在**是否需要扩容方面** 更优于HashMap，具体表现在，ConcurrentHashMap先检查此次插入是否会超出阈值，如果会就先执行扩容再进行插入；HashMap则是插入元素后判断是否已经达到容量，如果达到就进行扩容，~~但是这样很可能发生扩容后没有新元素的插入，这样就进行了一次无效的扩容。~~

* ConcurrentHashMap扩容不会对整个容器进行扩容，而是针对某个segment进行扩容

## get操作
```java
public V get(Object key) {
    Segment<K,V> s; 
    HashEntry<K,V>[] tab;
    // 获取该key的hash值
    int h = hash(key);
    // 对应的segment的偏移量
    long u = (((h >>> segmentShift) & segmentMask) << SSHIFT) + SBASE;
    // 如果查找到对应的segment
    if ((s = (Segment<K,V>)UNSAFE.getObjectVolatile(segments, u)) != null &&(tab = s.table) != null) {
        // 找到对应的Buckt进行遍历
        for (HashEntry<K,V> e = (HashEntry<K,V>) UNSAFE.getObjectVolatile
                (tab, ((long)(((tab.length - 1) & h)) << TSHIFT) + TBASE);
             e != null; e = e.next) {
            K k;
            if ((k = e.key) == key || (e.hash == h && key.equals(k)))
                return e.value;
        }
    }
    return null;
}
```
这里的操作不需要同步，因为Segment和HashEntry的值都是volatile类型，共享变量会对所有线程立刻可见。同一时间，volatile写 happens-before volatile读。

## size操作
虽然前面讲到Segment的count变量是volatile，但是并不意味着将所有segment的volatile变量加在一起就是size了，因为volatile只保证单个操作是原子性的，所以无法保证多个volatile变量相加后，其中一个volatile不会发生改变。但是如果在统计size时，将所有segment的写操作（put、clean等）锁住，又显得低效。

实际上，Segment的前两次统计都先不加锁执行，如果统计前的modCount和统计后的modCount不一致，那么就判断统计size失败。失败次数超过两次后，size方法就会将所有的segment加锁。