---
title: Painstaking4sllllllllll
date: 2018-06-30 00:14:35
tags: Test
---

个人觉得可能问到的问题：
* 启动Activity是哪个？
     看项目根目录瞎的AndroidManifest.xml
* 游戏是怎么展现在屏幕上的（抑或是说怎么做的这个游戏）



# 代码解析
## PvzActivity界面分析
这个Activity是整个程序唯一的Activity，所以程序一运行就先进入这个Acitivity，按生命周期顺序执行。
该Activity主要做了这么几件事：
1. 初始化导演类CCDirector
2. 给导演类CCDirector设置相关的属性
3. 创建一个欢迎场景

```java
    // PvzActivity.java

    // 这是cocos2d-x引擎（可以理解为框架）提供的类
    // 理解为“导演”，
    private CCDirector d = CCDirector.sharedDirector();
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        CCGLSurfaceView view = new CCGLSurfaceView(this);
        setContentView(view);
        
        // 将view设置给导演，告诉导演要在哪个View上进行操作
        d.attachInView(view);
        // 是否在界面上显示FPS，就是打开游戏后，左下角那个一直动的数字
        d.setDisplayFPS(true);
        // 设置每帧的时间。每一秒播放几个动画，这里1/60，相当于每秒播放60个动画
        d.setAnimationInterval(1.0f/60);
        // 设置view是横屏显示还是竖屏显示
        d.setDeviceOrientation(d.kCCDeviceOrientationPortrait);
        // 设置View的尺寸大小
        d.setScreenSize(480, 320);
        // 这是一个叫场景的东西。比如一个表演分为上中下，那么场景就是对应其中一个阶段
        // 整个游戏会有欢迎场景（即LoginScene），然后开始游戏后准备植物卡片的场景，最后是正式游戏的场景
        
        // 注意，这里仅仅是创建一个空白的场景
        CCScene scene = CCScene.node();
        
        // 我们这里才正式添加一个叫LoginScene的欢迎场景（一开始的登陆场景）
        scene.addChild(new LoginScene());
        // 让导演d 开始运行
        d.runWithScene(scene);
    }

    // 后面的代码都是一些模板代码，onPause、onDestroy这些...
    // 要是真问起来是干嘛的，就说是管理导演生命周期的东西
    ...
```

## LoginScene场景分析
前面讲到PvzActivity最后一步会启动欢迎界面，即LoginScene这个类

```java
    public LoginScene(){
		
		GameData.init();
		init();
		
		schedule("call", 0.5f);
		
	}
	public void call(float t){
		unschedule("call");//把call定时器销毁
		
		FaithLayer layer = new FaithLayer();
		this.addChild(layer, tagfailPop, tagfailPop);
		
		vh.changeScene(new HomeScene());
		
	}

	private void init() {
		//背景
		CCSprite bg = CCSprite.sprite("cover.jpg");
		bg.setScale(0.6f);
		bg.setAnchorPoint(0,0);
		this.addChild(bg, tagBg, tagBg);
		
		//累计天数
		CCSprite dayBg = CCSprite.sprite("well_detail.png");
		dayBg.setPosition(winSize.width/2, 36);
		this.addChild(dayBg,tagDayBg, tagDayBg);
		
		CCLabel label = CCLabel.labelWithString(
				CCDirector.theApp.getResources().getString(R.string.day1)+ViewService.getDays()
				+CCDirector.theApp.getResources().getString(R.string.day2)
				, font, 20);
		label.setAnchorPoint(0,0);
		label.setPosition(15, 25);
		dayBg.addChild(label, tagDayInfo, tagDayInfo);
		
		//进度条
		CCSprite bar = CCSprite.sprite("sc_publish_spin.png");
		bar.setPosition(winSize.width/2, winSize.height/2);
		this.addChild(bar, tagProgress, tagProgress);
		
		CCRotateBy by = CCRotateBy.action(1, 180);
		bar.runAction(CCRepeatForever.action(by));
		
		//版本号
		label = CCLabel.labelWithString("版本号:"+ViewService.getVersion(), font, 20);
		label.setAnchorPoint(0,0);
		label.setPosition(15, 25);
		label.setColor(ccColor3B.ccBLUE);
		this.addChild(label, tagVersion, tagVersion);
		
		
		
		
		
	}
	private final int tagBg = 1;//背景
	private final int tagDayBg = 5;
	private final int tagDayInfo = 10;
	private final int tagProgress = 15;
	private final int tagVersion = 20;
	private final int tagfailPop = 25;
```
