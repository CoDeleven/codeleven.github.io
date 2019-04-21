【查漏补缺】File的path、absolutePath和canonicalPath的区别

## 背景
在学习Idea的插件开发时，用到了相关的`VirtualFileSystem`这个东西，里面的`VirtualFile`有一个`getCanonicalPath()`方法引起了我的注意，我发现我不知道——



## 科普
首先知晓一下几个名词——**路径**、**绝对路径/相对路径**、**规范路径（不知道准不准确）**

然后考虑以下几种路径：

1. c:\temp\file.txt
2. .\file.txt
3. c:\temp\MyApp\bin\\..\\..\file.txt

第一类，属于路径，绝对路径，规范路径
第二类，属于路径，相对路径
第三类，属于路径，绝对路径

我们结合自己的开发经验，发现绝大多数情况都已经被覆盖到了，那么我们可以大致推测，`路径`包含`绝对路径/相对路径`，`绝对路径`包含`规范路径`，而`相对路径`不包含`规范路径`。

## 实战
```java
/* -------这是一个规范路径的代码------- */
File file = new File("C:\\Users\\W650\\Desktop\\701Studio\\app.js");
System.out.println("file.getAbsolutePath()  -> " + file.getAbsolutePath());
System.out.println("file.getCanonicalPath() -> " + file.getCanonicalPath());
System.out.println("file.getPath()          -> " + file.getPath());

/* -------输出------- */
file.getAbsolutePath()  -> C:\Users\W650\Desktop\701Studio\app.js
file.getCanonicalPath() -> C:\Users\W650\Desktop\701Studio\app.js
file.getPath()          -> C:\Users\W650\Desktop\701Studio\app.js
```

```java
/* -------这是一个绝对路径的代码(但不规范)------- */
File file = new File("C:\\Users\\W650\\Desktop\\701Studio\\utils\\..\\app.js");
System.out.println("file.getAbsolutePath()  -> " + file.getAbsolutePath());
System.out.println("file.getCanonicalPath() -> " + file.getCanonicalPath());
System.out.println("file.getPath()          -> " + file.getPath());

/* -------输出------- */
file.getAbsolutePath()  -> C:\Users\W650\Desktop\701Studio\utils\..\app.js
file.getCanonicalPath() -> C:\Users\W650\Desktop\701Studio\app.js
file.getPath()          -> C:\Users\W650\Desktop\701Studio\utils\..\app.js
```

```java
/* -------这是一个相对路径的代码------- */
File file = new File("..\\..\\..\\Test.txt");
System.out.println("file.getAbsolutePath()  -> " + file.getAbsolutePath());
System.out.println("file.getCanonicalPath() -> " + file.getCanonicalPath());
System.out.println("file.getPath()          -> " + file.getPath());

/* -------输出------- */
file.getAbsolutePath()  -> E:\commonWorkspace\IdeaPluginDevGuide\DevGuide-VirtualFileSystem\..\..\..\Test.txt
file.getCanonicalPath() -> E:\Test.txt
file.getPath()          -> ..\..\..\Test.txt
```

## 结论
1. 路径包含**绝对路径**和**相对路径**，**绝对路径**又包含了规范路径。
2. `getPath()`会返回给用户**创建File的路径**，`getAbsolutePath`会依据`调用该方法的类所在的路径 + 文件分隔符 + 创建File的路径`构造绝对路径，`getCanonicalPath()`一定返回规范的路径。

## 参考

 [What's the difference between getPath(), getAbsolutePath(), and getCanonicalPath() in Java?
](https://stackoverflow.com/questions/1099300/whats-the-difference-between-getpath-getabsolutepath-and-getcanonicalpath)