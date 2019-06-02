---
title: 《Java并发编程的艺术》之AtomicX
date: 2018-05-13 09:53:39
tags: [Java并发]
---

![](https://blog-1252749790.cos.ap-shanghai.myqcloud.com/JavaConcurrent/atomic_family.png)

其中主要是了解下```AtomicReference```以及```AtomicXUpdater```

AtomicReference是支持对象引用原子更新的类，仅仅是支持引用，如果要让对象内的字段支持原子更新，就一定要使用到AtomicXUpdater。

字段更新类需要特别注意，字段必须是```public volatile``` 类型的。

AtomicStampedReference和AtomicMarkableReference均是用于解决ABA问题的类（后者不知道有没有，暂时没实践经验）。前者解决字段方面的更新，后者解决引用类型的更新。