---
title: 《深入Java虚拟机》之类加载
date: 2018-06-08 18:45:09
tags: JVM
---

类加载总共分为以下几个阶段：
1. 加载
2. 验证
3. 准备
4. 解析
5. 初始化
6. 使用
7. 卸载

![](https://blog-1252749790.file.myqcloud.com/jvm/ClassLoading.png)

每个阶段并非按部就班的执行或完成，而是混合式进行的，通常会在一个阶段执行的过程中调用、激活。

类加载会在以下几种情况下被触发：
1. 遇到`new`、`putstatic`、`getstatic`、`invokestatic`这四条字节码指令时，如果类没有进行过初始化，则需先触发其初始化。上述四条指令分别对应：**创建新对象**、 **对静态字段赋值**、 **获取静态字段（对final属性无效，因为final属性在编译阶段就在常量池里）**、 **调用静态方法** 这四个场景。
2. 使用java.lang.reflect包的方法对类进行反射调用的时候，如果类没有进行过初始化，则先触发其初始化
3. 当初始化一个类时，该类的父类尚未初始化，则先初始化父类
4. 虚拟机启动时，初始化用户指定执行的 **包含main()方法的主类**
5. 当使用JDK7的动态语言支持时，如果一个`java.lang.invoke.MethodHandle`实例最后的解析结果是`REF_getstatic`、`REF_putstatic`、`REF_invokestatic`的方法句柄，并且这个方法句柄对应的类没有初始化，则触发初始化。

有且只有以上五种场景被成为 **主动引用**，除此之外所有引用类的方式都不会触发初始化。

## 被动式引用一
```java
class Super{
    static{
        System.out.println("Super Init");
    }
    static String hello = "nice";
}
class Sub{
    static{
        System.out.println("Sub Init");
    }
}

public static void main(String[] args){
    System.out.println(Sub.hello);
}

/** 
 * 最后会输出 "Super Init"
 * 因为调用的是Super类的hello字段
 */
```

## 被动式引用二
```java
public static void main(String[] args){
    Super[] supers = new Super[10];
}
/**
 * 该操作不会输出 "Super Init"
 * 因为虚拟机实例化的不是Super对象，而是 [Super
 * 该类由虚拟机生成，创建动作由字节码指令newarray触发
 */
```

## 被动式引用三
```java
class Super{
    static{
        System.out.println("Super Init");
    }
    static final String hello = "nice";
}

public static void main(String[] args){
    System.out.println(Super.hello);
}

/**
 * 该例子不会输出 "Super Init"
 * 因为final变量会在编译阶段就进入常量池
 */
```

---------------------

# 加载
在加载阶段，虚拟机需要完成以下三件事：
1. 通过一个类的全限定名读取该类的二进制文件（没有定义来源，可以是网络、ZIP包中读取的、生成的）
2. 将字节流里定义的静态数据结构转换成运行时数据结构
3. 在内存中生成一个代表这个类的java.lang.Class对象，在方法区内提供该类的数据入口

**类加载** 过程中，加载这个阶段对 **非数组类**的限制是最少的，开发人员对其的可控性也是最高的。因为加载阶段可以由开发人员提供自定义的ClassLoader（覆盖loadClass()方法）

对于 **数组类**来说，数组类本身不会通过类加载器创建，它是由虚拟机直接创建的。不过数组类的元素类型（去掉所有维度的类型）最终是要靠类加载器去创建的：
* 如果数组的组件类型（数组去掉一个维度的类型）是引用类型，那么就正常加载，数组C会在 **加载该组件类型的类加载器的类名称空间里** 被标记
* 如果数组的组件类型不是引用类型（比如int[])，那么虚拟机会把数组标记为与引导类加载器关联
* 数组类的可见性与它的组件类型的可见性一致，如果组件类型不是引用类型，那数组类的可见性将默认为public

加载完毕后，类的二进制流会按照虚拟机所需的格式存放在方法区内，然后在内存中实例化一个Class类的对象（不同虚拟机里实现不同，HotSpot里，Class对象是存放在方法区里面），这个对象作为程序访问方法区数据的入口。

加载阶段和连接阶段是交叉进行的，下一个阶段会在加载阶段尚未完成的时候就开始。夹在加载阶段之中进行的动作，仍然属于连接阶段，这两个阶段的开始时间仍然保持着固定的先后顺序。

# 验证
该阶段主要验证来源不明的Class文件，因为Class文件可以通过16进制修改器直接修改，如果完全新任，不检查它，可能会因为载入有害的字节流而导致系统崩溃。该阶段直接决定了虚拟机是否能承受恶意的代码攻击。该阶段分为四个部分：
1. 文件格式验证
2. 元数据验证
3. 字节码验证
4. 符号引用验证

## 文件格式验证
因为字节流的来源不明，所以需要校验一下文件格式是否符合Class文件的定义：
* 是否以魔数 0xCAFEBABE 开头
* 主、次版本号是否在当前虚拟机处理范围之内
* 常量池的常量中是否有不被支持的常量类型
* 指向常量的各种索引值中是否有指向不存在的常量或不符合类型的常量
* CONSTANT_Utf8_info 型的常量中是否有不符合UTF8编码规范的数据
* Class文件中各个部分及文件本身是否有被删除或附加的信息
* ......

该阶段的目的是保证输入的字节流能被正确解析成方法区的数据结构并存于方法区之内，只有经过这个阶段，字节流才会进入内存的方法区中进行存储，所以后面的阶段都是基于方法区的存储结构进行的，不会再直接操作字节流。

## 元数据验证
对类的信息进行语义分析，保证每个类符合规范：
* 这个类是否有父类（除了Object类以外，所有类都应该有父类）
* 这个类的是否继承了不该继承的类（被final修饰的类）
* 如果这个类不是抽象类且继承了抽象类（或接口），是否实现了其父类的所有抽象方法（或实现接口的所有方法）
* 类中的字段、方法是否与父类产生矛盾（覆盖了父类的final字段，或者出现不符合规则的方法重载，例如方法签名都一样，但是返回值不同）
* ......

第二阶段的主要目的是对元数据信息进行语义检验，保证不存在不符合Java规范的元数据信息。

## 字节码验证
主要校验代码逻辑是否正确：
* 保证操作数栈的类型和指令代码序列能一一对应。比如从操作数栈取出的类型为int，而指令代码序列却是用long类型
* 保证跳转指令不会跳转到方法体以外的字节码指令上
* 保证方法体中的类型转换是有效的
* ......

如果类文件没通过字节码验证，那么一定是不安全的；如果通过字节码验证，也不能说明绝对安全。一个著名的问题——停机问题，可以告诉我们程序不可能准确算出程序是否能在有限时间结束。

JVM为了解决检验时间过长的问题，在方法的code属性表中增加了一项名为“StackMapTable”的属性，这项属性描述了方法体中所有的基本块（按照控制流拆分的代码块）开始时本地变量表和操作栈应有的状态，在字节码验证期间，就不需要根据程序推导这些状态的合法性，只需要检查StackMapTable中的记录是否合法即可。同样，该属性也有被篡改的可能。

## 符合引用验证
该阶段的校验发生在虚拟机将符号引用转换为直接引用的时候，这个转换动作将在连接的第三阶段——解析阶段中发生。主要作用就是检验各个引用是否存在匹配项：
* 全限定名是否能找到对应的类
* 指定类中是否存在符合方法的字段描述符以及简单名称所描述的方法和字段

如果开发人员对所有的代码都很了解，确定没有恶意代码，可以考虑使用 `-Xverify:none` 参数来关闭大部分类的验证措施，以缩短虚拟机的加载时间

# 准备
该阶段只会初始类里面的static域（不会初始化实体类的普通属性），通常情况下会将static域初始化成默认值（int为0，float为0.0等等）

而如果该static域被final修饰了，那么当该属性所属的类在编译期就会产生一个ConstantValue。在类的加载过程中，static域就会被初始化为对应的ConstantValue

```java
public static int a = 128;
// 当在准备阶段时，该类的a属性被初始化为0
```

```java
public static final int a = 128;
// 在编译期时，128作为ConstantValue被存储到Class文件中
// 在准备阶段时，该类的a属性值立刻被初始化为128
```

# 解析
虚拟机将常量池内的符号引用转换成直接引用的过程，符号引用在Class文件中以 CONSTANT_Class_info 、CONSTANT_Methodref_info、CONSTANT_Field_info形式进行记录。

* 符号引用：符号引用以一组符号来描述所引用的目标，符号可以是任何形式的字面量，只要使用时能无歧义地定位到目标即可。符号引用在各虚拟机里表现不同，内存布局也不同，但是虚拟机能够接受的符号引用都是一样的，因为这是java虚拟机规范
* 直接引用：直接引用是一个在运行时的概念，可以是指向目标的指针、相对偏移量或是一个能间接定位到目标的句柄。直接引用和内存布局是相关的，同一个符号引用在不同虚拟机上会转换出的直接引用一般不同。如果有了直接引用，那引用目标必定已经存在内存里了。

虚拟机会在遇到以下指令之前触发解析
* anewarray
* checkcast
* getfield
* getstatic
* instanceof
* invokedynamic
* invokeinterface
* invokespecial
* invokestatic
* invokevirtual
* ldc
* ldc_w
* multianewarray
* new 
* putfield
* putstatic
这16个指令囊括一下就有以下的规律：
* 创建的时候——anewarray、new、multianewarray、ldc、ldc_w（后两个创建字符串时会触发
* 类型判断或转换的时候——checkcast、instanceof
* 调用方法时——invokedynamic、invokeinterface、invokespecial、invokestatic、invokevirtual
* 获取字段/赋值——getfield、getstatic、putfield、putstatic

触发解析阶段可能会在加载类时就触发，也可能运行到以上指令前触发，这是根据具体虚拟机的实现而定的。

除invokedynamic指令以外的指令满足如下条件：
虚拟机可能会对同一个符号引用调用很多次，但是虚拟机通常会将第一次解析结果进行缓存（通过在运行时常量池记录直接引用以及标记符号引用已被解析），但是仍然会发生多次解析同一个符号引用的情形，那么虚拟机需要保证第一次解析成功，后续对其的解析也必须成功；同理，如果第一次解析失败，后续的解析都要抛出相同的异常。

而invokedynamic之所以如此特别，主要在于它是用于动态语言的指令，它所对应的引用称为 **动态调用限定符**，这里动态的意思是指必须等到实际程序运行到该条命令时，解析动作才能进行。其余的指令，可以在运行到指令前（加载时）就可以触发解析。

## 类解析
当解析类或接口时，假设当前执行的代码类是D。
如果遇到了一个类，需要把一个从未解析过的符号引用N解析为一个类或接口C的直接引用，虚拟机要完成以下三个步骤：
1. 如果该类不是数组类，那虚拟机会将代表N的全限定名传给D的类加载器去加载该类或接口C。在加载过程中，无论哪个阶段抛出异常，解析过程就宣告失败。
2. 如果该类是数组类，并且数组元素的类型为对象，也就是N的描述符是类似"[java/lang/String"的形式，那么会采用第一点的规则加载数组元素类型。假设N的描述符和上述一样，那么需要加载的数组元素类型就是"java.lang.String"，接着会由虚拟机生成一个代表此维度和元素的数组对象
3. 如果上面的步骤没有问题，那么C已经成为一个有效的类或接口，但在解析完成之前还要进行符号引用验证，即确认D是否具备对C的访问权限。如果发现不具备，将抛出java.lang.IllegalAccessError。

## 字段解析
要解析一个未被解析过的字段符号引用，首先需要对该字段所处的类进行解析，也就是类或接口的符号引用。如果在解析这个类或接口过程中失败，都会导致字段符号引用的解析失败。如果解析成功完成，那将这个字段所属的类或接口用C表示，虚拟机会后续对字段符号引用进行如下查找：
1. 如果C本身就是该字段的引用类型，且简单名称和字段描述符都与目标字段相匹配，则返回这个字段的直接引用，查找结束
2. 否则，如果C实现了接口，那么就从接口里（递归查找）进行查找，如果接口中包含了简单名称和字段描述都与目标字段相匹配，则返回这个字段的直接引用。
3. 否则，如果C继承了父类，那么就从父类进行递归查找，如果在父类中包含了简单名称和字段描述符都与目标字段相匹配的字段，则返回这个字段的直接引用。
4. 否则查找失败，抛出NoSuchFieldError异常
5. 查找成功后，进行访问权限的校验

注意，实际虚拟机的编译器实现会比上述更严格一些，即实现的接口、继承的类都声明了同个字段，可能会提示字段混淆的异常。

## 类方法解析
对于被调用的方法，先解析它所属类或接口的符号引用，如果解析成功，我们依然用C表示这个类，接下来会按以下的规则进行查找：
1. 类方法和接口方法的符号引用定义是分开的，先校验C这个类继承的是否正确，比如原本继承的AInterface是接口类型，在运行时如果AInterface变成抽象类，那么就会报错：IncompatibleClassChangeError
2. 如果通过第一步，那么在C里查找简单名称和描述符都匹配的目标方法，找到则返回其直接引用
3. 否则在C的父类中递归查找是否有简单名称和描述符都匹配的目标方法，找到则返回其直接引用
4. 否则在C实现的接口列表及它们的父接口中递归查找简单名称和描述符都匹配的目标方法，如果存在匹配方法，说明类C是抽象类方法（因为前面的可能都不存在），抛出AbstractMethodError
5. 否则，抛出NoSuchMethodError
6. 返回直接引用时，并对这个方法进行权限校验

>Your newly packaged library is not backward binary compatible (BC) with old version. For this reason some of the library clients that are not recompiled may throw the exception.
>This is a complete list of changes in Java library API that may cause clients built with an old version of the library to throw java.lang.IncompatibleClassChangeError if they run on a new one (i.e. breaking BC):
> Non-final field become static,

> Non-constant field become non-static,

> Class become interface,

> Interface become class,

> if you add a new field to class/interface (or add new super-class/super-interface) then a static field from a super-interface of a client class C may hide an added field (with the same name) inherited from the super-class of C (very rare case).


## 接口方法解析
对于被调用的接口，先查找该方法所属的接口，如果解析成功，我们用C表示这个类，接下来按以下的规则进行查找：
1. 类方法和接口方法的符号引用定义是分开的，先校验C这个类继承的是否正确，比如原本继承的AInterface是接口类型，在运行时如果AInterface变成抽象类，那么就会报错：IncompatibleClassChangeError
2. 如果通过第一步，那么在C里查找简单名称和描述符都匹配的目标方法，找到则返回其直接引用
3. 否则查找C的父类接口，直到java.lang.Object，如果找到简单名称和描述符都匹配的目标方法，找到则返回其直接引用
4. 否则抛出，NoSuchMethodError
由于interface里面都是public方法，所以不用校验权限

# 初始化
类加载阶段里的准备阶段已经将常量（final修饰）的变量进行初始化为给定数值，把非常量的静态变量初始化为默认值。而该阶段就是将非常量的静态变量按照开发人员的意图进行初始化：
1. 编译期收集一个类的全部静态类型（包括static字段、static块）
2. 按收集顺序（程序里的排列顺序）依次排序到 <cinit>

<cinit>不是必须的，如果父类或者接口类没有静态字段或者静态块，编译期就不会生成<cinit>方法。另外，与类不同的是，接口的静态字段需要等到用户真正调用时才会初始化。遇到多个线程初始化同一个类的情况时，虚拟机会保证只有一个线程执行<cinit>，其他线程就会进入阻塞状态直到该线程执行完初始化；

虚拟机会保证先执行父类的<cinit>，再执行子类的<cinit>，所以java.lang.Object一定是第一个被初始化的类。

![](https://blog-1252749790.file.myqcloud.com/jvm/classload_summary.png)