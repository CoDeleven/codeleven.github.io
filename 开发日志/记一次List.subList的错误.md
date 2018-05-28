---
title: 标题没想好，不过一定是写List集合的
date: 2018-04-24 22:31:43
tags: Java集合
---



以后有空完整了解下ArrayList和相关集合
这次先解决一个这样的问题，看下面代码：

```java
List<Integer> foo = new ArrayList<>();
for(int i = 0; i < 10; ++i){
    foo.add(i);
}
List<Integer> foo1 = foo.subList(0, 3);
List<Integer> foo2 = foo.subList(3, 5);
foo2.add(1);
System.out.println(foo1.size());
```

读者感觉是否挺正常的，没有**迭代**，没有在**多线程**下，单纯的给*foo1*列表添加一个值好像没什么问题。但是在运行后会抛出“ConcurrentModificationException”，这就很气了。博主因为这个问题思来想去，从**迭代**到**多线程**，每个角度都思考过，后来进入源码一看
```java
// SubList是ArrayList的内部类
/* parent = ArrayList.this
 * offset = 0
 * 剩下两个就不用解释了
 */
SubList(AbstractList<E> parent,
        int offset, int fromIndex, int toIndex) {
    this.parent = parent;
    this.parentOffset = fromIndex;
    this.offset = offset + fromIndex;
    this.size = toIndex - fromIndex;
    // 注意，这里从ArrayList.this获取了modCount
    this.modCount = ArrayList.this.modCount;
}
```
在进入add等修改方法后，可以看到最终递增modCount的方法
```java
private void ensureExplicitCapacity(int minCapacity) {
    // 可以看到，这里递增的只是ArrayList.this的modCount
    modCount++;
    // overflow-conscious code
    if (minCapacity - elementData.length > 0)
        grow(minCapacity);
}
```
所以通过*size()*，*add()*等方法对*SubList内部类*的修改会引起*外部类的modCount变化*，但是*其他内部类的modCount* (作修改的内部类的modCount会改变)不改变就会产生不一致，所以抛出这个异常