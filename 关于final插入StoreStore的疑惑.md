---
title: 关于final插入StoreStore的疑惑
date: 2018-04-29 11:13:43
tags: JVM
---

在学习volatile和final时，注意到写时的区别：

1. volatile写时往前面插入StoreStore内存屏障，保证第一个操作先发生于volatile写
2. final在构造函数时在final写后插入StoreStore内存屏障，保证final写先发生于后面的操作

想必大家经常会听到volatile会保证 volatile写前的所有操作先执行完再执行volatile写。

而在**对final域和普通域初始化的构造函数**里，即使final写前面有StoreStore，前面的普通写/读仍然会发生重排序？？
