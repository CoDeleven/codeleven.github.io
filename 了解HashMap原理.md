---
title: 了解HashMap原理
date: 2018-04-05 19:51:39
tags: Java集合
---

对于写了这么久的HashMap，对其知之甚少，趁大三有点闲时，打算深入了解下HashMap的原理。

1. HashMap、HashTable之间有什么关系
2. HashMap在put、remove的时候做了什么
3. resize（再哈希）是什么
4. 为什么每次扩容，容量都是原来的二次方


## HashMap和HashTable间的关系
HashMap和HashTable间的差异：
1. HashMap是线程不安全的,HashTable几乎都加上了方法级别的Synchronize，所以同一时间最多只有一个线程可以对同个方法进行调用
2. HashMap允许null键和null值,HashTable遇到null值会抛出NPE

    HashTable的源码分析戳这里
## HashMap再put、remove的时候做了什么

### JDK6
```java
/**
 * 第一次注意到put有返回值
 * 如果put之前key已经存在和值X的对应关系，则返回值X
 * 如果put之前key没有对应关系，则返回null
 */
public V put(K key, V value) {
    // 当key为null时，特殊处理，这是和HashTable不一样的地方
    // HashMap允许key、value为null
    if (key == null)
        return putForNullKey(value);
    // hash一下，这里用到的是扰动函数
    int hash = hash(key.hashCode());
    // 获取该hash值的bucketIndex
    int i = indexFor(hash, table.length);
    // 遍历对应bucktIndex位置的Entry
    for (Entry<K,V> e = table[i]; e != null; e = e.next) {
        Object k;
        // 比较该bucktIndex下的所有Entry
        // 比较hash值、比较key是否相等（从值和地址两方面进行比较）
        // 为什么要再比较次hash值
        if (e.hash == hash && ((k = e.key) == key || key.equals(k))) {
            V oldValue = e.value;
            e.value = value;
            e.recordAccess(this);
            return oldValue;
        }
    }
    // fail-fast的计数器
    modCount++;
    // 添加新值
    addEntry(hash, key, value, i);
    return null;
}
private V putForNullKey(V value) {
    // 从Entry数组下标为0的位置开始一一遍历
    for (Entry<K,V> e = table[0]; e != null; e = e.next) {
        // 是否存在这么一个entry，其key为null
        // 如果存在则替换新值
        if (e.key == null) {
            V oldValue = e.value;
            e.value = value;
            // 钩子函数
            // 可以看一下LinkedHashMap
            e.recordAccess(this);
            return oldValue;
        }
    }
    // 计数器加一
    modCount++;
    // 新添加一个键值对
    addEntry(0, null, value, 0);
    return null;
}
void addEntry(int hash, K key, V value, int bucketIndex) {
    // 获取下该bucketIndex下的Entry
    Entry<K,V> e = table[bucketIndex];
    // 产生了hash冲突。将Old Entry连接到New Entry后面
    table[bucketIndex] = new Entry<K,V>(hash, key, value, e);
    // 判断是否要再hash
    if (size++ >= threshold)
        // 因为capacity本身就是2的n次方，见HashMap的初始方法
        // 所以每次扩大，只需要*2
        resize(2 * table.length);
}
void resize(int newCapacity) {
    Entry[] oldTable = table;
    int oldCapacity = oldTable.length;
    if (oldCapacity == MAXIMUM_CAPACITY) {
        threshold = Integer.MAX_VALUE;
        return;
    }

    Entry[] newTable = new Entry[newCapacity];
    // 移动数组
    transfer(newTable);
    table = newTable;
    threshold = (int)(newCapacity * loadFactor);
}
void transfer(Entry[] newTable) {
    Entry[] src = table;
    int newCapacity = newTable.length;
    // 遍历全部的Entry
    for (int j = 0; j < src.length; j++) {
        Entry<K,V> e = src[j];
        // 如果该BucketIndex存在数值
        if (e != null) {
            src[j] = null;
            do {
                // 保存下一个Entry
                Entry<K,V> next = e.next;
                // 获取该e对象在新entry数组的index
                int i = indexFor(e.hash, newCapacity);
                // 是否发生hash冲突，如果有，就接到e对象的后面，没有就是null
                e.next = newTable[i];
                // 将e设置到对应的位置
                newTable[i] = e;
                e = next;
            } while (e != null);
        }
    }
}
```
### JDK7
在JDK6的基础上，没有做特别的改变，倒是去除了modCount的volatile关键字(1.7取消了modCount的volatile)。

移除volatile的原因:
对于单线程集合，没必要承担volatile的额外消耗；多线程情况下，也不应该使用单线程集合，所以在hashmap里面移除volatile

[移除Volatile的原文](https://bugs.sun.com/bugdatabase/view_bug.do?bug_id=6625725)

### JDK8
需要红黑树的知识，待学习

## 再哈希
```java
/**
 * 扩容，根据key的hash和数组总长度重新hash获取新的BucketIndex，然后存放
 * 因为不是线程安全的，再哈希可能会发生死循环
 */
void resize(int newCapacity) {
    Entry[] oldTable = table;
    int oldCapacity = oldTable.length;
    if (oldCapacity == MAXIMUM_CAPACITY) {
        threshold = Integer.MAX_VALUE;
        return;
    }

    Entry[] newTable = new Entry[newCapacity];
    // 移动数组
    transfer(newTable);
    table = newTable;
    threshold = (int)(newCapacity * loadFactor);
}
```
## 每次扩容，容量都是原来的二次方
容量都是2的N次，主要是为了下面的```indexFor()```埋下伏笔，我们在使用```HashMap```最希望它的Entry能平均分布，那样找起来更高效。我们想到的第一个算法就是```hash % length```，先保证不超过最大长度，其次保证hash坐落的位置。但是取模运算是所有运算符里较为繁杂的运算指令。大师们为了更高效，就不得不采用位运算符并让```hash```的每位都参与到运算中。这里放出式子```hash & (length - 1)```

```java
/** 
 * Returns index for hash code h. 
 */  
static int indexFor(int h, int length) {  
    return h & (length-1);  
}  
```

可以看一下，如果容量的长度不是2的幂次方
```
length: 1000 0000
          &
hash:   0110 1111
```
上述例子实际可存放的位置就只有一个: **1000 0000** ，会有大量的空间被浪费，```hash```的很多位没有参与到运算中去，增大了hash冲突，所以应该尽可能的让所有位都是1，那么理想状况下应该是如下所示

```
length: 1111 1111
          &
hash:   0110 1111
```
但是这样的容量很难通过一次移位获取，所以实际情况应该是2的N次方 - 1，尽可能的将1布满。如下所示

```
length: 0111 1111
          &
hash:   0110 1111
```
通过移位获取最大的2的N次方，减去1，获得最可能的理想情况，允许存在128个位置。一个是256，一个是255，前者只能存放1个位置，后者可以存放128个位置，其高效可想而知。

所以容量是2的幂次方是为了减少空间的浪费，降低hash冲突的几率

