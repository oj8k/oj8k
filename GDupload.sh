#!/bin/bash
path="$3" #取原始路径，我的环境下如果是单文件则为/data/demo.png,如果是文件夹则该值为文件夹内某个文件比如/data/a/b/c/d.jpg
downloadpath='/data/aria2/download' #下载目录
rclone='/home/GoogleDrive'   #rclone挂载的目录

if [ $2 -eq 0 ] #下载文件为0跳出脚本
        then
                exit 0
fi

while true; do  #提取下载文件根路径，如把/data/a/b/c/d.jpg变成/data/a
    filepath=$path
    path=${path%/*}; 
    if [ "$path" = "$downloadpath" ] && [ $2 -eq 1 ]
        then
        rclone=${filepath/#$downloadpath/$rclone} #替换路径
        mv -f "${filepath}" "${rclone}"
        exit 0
    elif [ "$path" = "$downloadpath" ]   #文件夹
        then
        mv -f "${filepath}" "${rclone}"/
        rm -rf  "${filepath}"
        exit 0
    fi
done