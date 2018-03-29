#! /bin/bash

#*****************
# GOST搭建脚本
# by supppig
#  v2.0
#****************

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear
echo

echo

#Current folder
cur_dir=`pwd`

# Make sure only root can run our script
function rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error:This script must be run as root!" 1>&2
       exit 1
    fi
}

# Check OS
function checkos(){
    if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}


# Pre-installation settings
function pre_install(){
    # Not support CentOS 5
    if centosversion 5; then
        echo "Not support CentOS 5, please change OS to CentOS 6+/Debian 7+/Ubuntu 12+ and retry."
        exit 1
    fi
    # Set gost password
	echo "***************"
	echo " GOST搭建脚本"
	echo " by supppig"
	echo "    v2.0"
	echo "  2017.2.25"
	echo "***************"
	echo ""
    echo "输入gost的密码（请只使用数字和字母组合，不要用点，中下划线等特殊字符，以免出现兼容性问题）:"
    read -p "(默认密码: supppig):" gostpwd
	[ -z "$gostpwd" ] && gostpwd="supppig"
	echo
	if ! [[ $gostpwd =~ ^[a-zA-Z0-9]+$ ]];then
	echo -e "\033[44;31m 密码里混进了奇怪的字符！密码改为默认密码supppig。请在脚本之后完毕后用“gost set”命令重新设置密码！\033[0m"
	gostpwd="supppig"
	fi
    echo "---------------------------"
    echo "password = $gostpwd"
    echo "---------------------------"
    echo
	
	echo "输入gost的端口。此端口与是否免流完全无关。默认6688。"
	echo "若修改端口，则sussr脚本的对应端口也需要修改。"
    read -p "gost端口(默认6688):" gostport
    [ -z "$gostport" ] && gostport="6688"
    echo
	if ! [[ $gostport =~ ^[0-9]+$ ]];then
	echo -e "\033[44;31m端口里混进了奇怪的字符！端口改为默认端口6688。请在脚本之后完毕后用“gost set”命令重新设置端口！\033[0m"
	gostport="6688"
	fi
    echo "---------------------------"
    echo "gost端口 = $gostport"
    echo "---------------------------"
    echo	
    echo "选择下载源，1是国内源（TaoCode），2是国外源（github）。按照vps所处的地理位置选择，可以加快下载速度。"
    read -p "(默认国内源):" xzy
    [ -z "$xzy" ] && xzy="1"
    echo
    echo "---------------------------"
    echo "下载源 = $xzy"
    echo "---------------------------"
    echo	
		
	if [ "$xzy" == "2" ];then
	    xzy="http://wuyi-1251424646.costj.myqcloud.com/gost_2.3_linux_amd64.tar.gz"
    else
	    xzy="http://wuyi-1251424646.costj.myqcloud.com/gost_2.3_linux_amd64.tar.gz"
	fi
	
	# Install necessary dependencies
	type killall 2>/dev/null >/dev/null
	if [ $? -ne 0 ];then
	echo "安装killall"
    if [ "$OS" == 'CentOS' ]; then
        yum install -y psmisc
    else
        apt-get install -y psmisc
    fi
	fi
}

# Download files
function download_files(){
	cd $cur_dir
    if ! wget --no-check-certificate $xzy -O gost_2.3_linux_amd64.tar.gz; then
        echo "文件下载失败!"
        exit 1
    fi
	uninstall_gost >/dev/null
	tar -zxf gost_2.3_linux_amd64.tar.gz -C /usr/local
	mv /usr/local/gost_2.3_linux_amd64 /usr/local/gost
	mv /usr/local/gost/gost /usr/local/gost/gostproxy
	chmod 777 /usr/local/gost/gostproxy
}

# firewall set
function firewall_set(){
    echo "配置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${gostport}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${gostport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${gostport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口${gostport}已经建立过了。。"
            fi
        else
            echo "警告: iptables貌似没有安装。（能正常用就不用管）"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${gostport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${gostport}/udp
            firewall-cmd --reload
        else
            echo "防火墙貌似没有运行，正在启动~~"
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=${gostport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${gostport}/udp
                firewall-cmd --reload
            else
                echo "警告: 启动防火墙失败~~（能正常用就不用管）"
            fi
        fi
    fi
    echo "防火墙配置完成！"
}

# Config
function config_gost(){
	rm -f /usr/local/gost/gost.json
    echo "{
    \"ServeNodes\": [
        \"socks://supppig:${gostpwd}@:${gostport}\"
    ]
}
" > /usr/local/gost/gost.json
}

#获取配置文件
function get_conf(){
#文件存在
filename="/usr/local/gost/gost.json"
if [ -s $filename ];then
#取密码
gostpwd=$(cat $filename | grep 'supppig' | cut -d':' -f3 | cut -d'@' -f1)
#取端口
gostport=$(cat $filename | grep 'supppig' | cut -d':' -f4 | cut -d'"' -f1)
echo -e "gost密码:\033[41;37m${gostpwd}\033[0m  gost端口:\033[41;37m${gostport}\033[0m"
else
echo "gost配置文件缺失！请重新配置！"
fi
}

#停止gost
function stop_gost(){
	#兼容旧版本
	killall -15 -w gost 2>&-
	sleep 1
	killall -9 -w gost 2>&-
	##
	killall -15 -w gostproxy 2>&-
	sleep 1
	killall -9 -w gostproxy 2>&-
}

#检查gost状态
function check_gost(){
pid_line=$(ps -ef | grep 'gostproxy' | grep -v 'grep')
if [ "$pid_line" != "" ];then
echo -e "\033[34m gost正在运行。。。\033[0m"
get_conf
else
echo -e "\033[31m gost没有运行！！！\033[0m"
fi
}

#开始gost  --lite
function start_gost(){
nohup /usr/local/gost/gostproxy -C /usr/local/gost/gost.json >/dev/null &
}

#卸载gost
function uninstall_gost(){
	stop_gost
	rm -rf "/usr/local/gost" 
	rm -rf "/usr/local/sbin/gost"
}

#生成控制脚本
function make_sh(){
cat > /usr/local/sbin/gost <<'GOST'
#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Check OS
function checkos(){
    if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}

# firewall set
function firewall_set(){
    echo "配置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${gostport}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${gostport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${gostport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口${gostport}已经建立过了。。"
            fi
        else
            echo "警告: iptables貌似没有安装。（能正常用就不用管）"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${gostport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${gostport}/udp
            firewall-cmd --reload
        else
            echo "防火墙貌似没有运行，正在启动~~"
            systemctl start firewalld
            if [ $? -eq 0 ];then
                firewall-cmd --permanent --zone=public --add-port=${gostport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${gostport}/udp
                firewall-cmd --reload
            else
                echo "警告: 启动防火墙失败~~（能正常用就不用管）"
            fi
        fi
    fi
    echo "防火墙配置完成！"
}


# Config
function config_gost(){
	rm -f /usr/local/gost/gost.json
    echo "{
    \"ServeNodes\": [
        \"socks://supppig:${gostpwd}@:${gostport}\"
    ]
}
" > /usr/local/gost/gost.json
}

#获取配置文件
function get_conf(){
#文件存在
filename="/usr/local/gost/gost.json"
if [ -s $filename ];then
#取密码
gostpwd=$(cat $filename | grep 'supppig' | cut -d':' -f3 | cut -d'@' -f1)
#取端口
gostport=$(cat $filename | grep 'supppig' | cut -d':' -f4 | cut -d'"' -f1)
echo -e "gost密码:\033[41;37m${gostpwd}\033[0m  gost端口:\033[41;37m${gostport}\033[0m"
else
echo "gost配置文件缺失！请重新配置！"
fi
}

#停止gost
function stop_gost(){
	killall -15 -w gostproxy 2>&-
	sleep 1
	killall -9 -w gostproxy 2>&-
}

#卸载gost
function uninstall_gost(){
	stop_gost
	rm -rf "/usr/local/gost" 
	rm -rf "/usr/local/sbin/gost"
	echo "卸载gost完成~~"
}

#检查gost状态
function check_gost(){
pid_line=$(ps -ef | grep 'gostproxy' | grep -v 'grep')
if [ "$pid_line" != "" ];then
echo -e "\033[34m gost正在运行。。。\033[0m"
else
echo -e "\033[31m gost没有运行！！！\033[0m"
echo -n "配置文件中："
fi
get_conf
}

#开始gost
function start_gost(){
stop_gost
nohup /usr/local/gost/gostproxy -C /usr/local/gost/gost.json >/dev/null 2>&1 &
sleep 1
check_gost
}

#设置密码及端口
function set_gost(){
if [ -z "$1" ];then
echo "set用法：
gost set 密码 端口
其中密码是必须项，端口默认6688."
exit 1
fi
gostpwd="$1"
gostport="$2"
[ -z "$gostport" ] && gostport="6688"

if ! [[ $gostpwd =~ ^[a-zA-Z0-9]+$ ]];then
echo -e "\033[44;31m 密码里混进了奇怪的字符！设置失败！\n密码仅支持使用大小写字母及数字！\033[0m"
exit 1
fi
if ! [[ $gostport =~ ^[0-9]+$ ]];then
echo -e "\033[44;31m端口里混进了奇怪的字符！设置失败！\033[0m"
exit 1
fi

echo "正在设置新密码：$gostpwd  新端口：$gostport"
stop_gost
config_gost
if [ "$OS" == 'CentOS' ]; then
    firewall_set 2>&-
fi
echo "修改密码和端口完成。正在重启~~"
start_gost
}

function help_gost(){
echo "gost控制脚本帮助
by supppig @ 2017.2.25

支持的命令：
gost start  :开启/重启gost
gost stop   :停止gost
gost check  :检查gost状态/查看密码及端口
gost set 密码 端口 :重新设置密码和端口（密码必须输入，端口可选。留空表示6688）
gost uninstall  :卸载gost！
gost help   : 输出这个帮助命令
"
}

checkos
case "$1" in
"start")
	echo "正在执行开启gost命令~"
	start_gost
	;;
"stop")
	echo "正在执行关闭gost命令~"
	stop_gost
	check_gost
	;;
"check")
	check_gost
	;;
"set")
	set_gost "$2" "$3"
	;;
"help")
	help_gost
	;;
"uninstall")
	uninstall_gost
	;;
*)
	check_gost
	echo "输入 gost help 获得更多帮助信息。"
	;;
esac
echo -e "\033[42;44mby supppig @ 2017.2.25\033[0m"

GOST

chmod 777 /usr/local/sbin/gost
echo "控制脚本已生成~"
}

checkos
rootness
pre_install
download_files
config_gost
if [ "$OS" == 'CentOS' ]; then
    firewall_set 2>&-
fi

start_gost

cd $cur_dir
rm -f gost_2.3_linux_amd64.tar.gz
rm -f gost.sh
rm -f gost.sh* 2>&-

clear
	echo "***************"
	echo " GOST搭建脚本"
	echo " by supppig"
	echo "    v2.0"
	echo "  2017.2.25"
	echo "***************"
	echo ""
check_gost
make_sh
echo ""
echo -e "服务器端已经搞定~
运行\033[31m gost help \033[0m获得更多帮助
\033[42;44mby supppig @ 2017.2.25\033[0m

"


