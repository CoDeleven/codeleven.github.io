# hexo��Ŀ¼
$blogRootDir = 'E:\blog\blogSource'
# hexo����ļ�
$blogDeployDir = "E:\blog\blogSource\source\_posts\"
# �ҵĲ��͹鵵Ŀ¼
$myAchieveDir = 'E:\blog\codeleven.github.io'

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