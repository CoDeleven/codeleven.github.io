# -*- coding=utf-8
import os


def listDir(path):
    fileArray = os.listdir(curPath)
    print(fileArray)
    for fileName in fileArray:
        if(fileName.find(".py") != -1):
            continue
        count = 0
        fileTarget = open(fileName, encoding='UTF-8', mode='a+')
        fileTarget.seek(0, 0)
        lastLine = 0
        while True:
            line = fileTarget.readline()
            if(not line):
                break
            if(isUrlExists(line)):
                count += 1
                fileTarget.seek()
                print(fileTarget.tell())
                # line.replace(r'ComputerOrganization/',
                #              r'ComputerOrganization/Bus/')
            lastLine = line
        print('File: %s ---- 修改了 %d 行' % (fileName, count))


def isUrlExists(line):
    if(line.find(r'ComputerOrganization/') != -1):
        return True
    else:
        return False


curPath = os.path.abspath('.')
listDir(curPath)
