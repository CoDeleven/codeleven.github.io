# hexo根目录
$blogRootDir = 'E:\commonWorkspace\blog\blogSource'
# hexo里的文件
$blogDeployDir = "E:\commonWorkspace\blog\blogSource\source\_posts\"
# 我的博客归档目录
$myAchieveDir = 'E:\commonWorkspace\blog\codeleven.github.io'

if(Test-Path $blogDeployDir){
    del $blogDeployDir -confirm    
}

md $blogDeployDir

Set-Location $myAchieveDir

$allDir = Dir -Directory
foreach($i in $allDir){
    $fileInDir = Dir .\ -Include *.md -Recurse
    foreach($item in $fileInDir){
        Copy-Item $item $blogDeployDir
    }
}

Set-Location $blogRootDir

hexo clean

hexo generate

hexo deploy