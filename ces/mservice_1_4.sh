#! /bin/bash
set -e

# check net
ping -q -w 1 -c 1 www.baidu.com > /dev/null || (echo "Plese check your network." && exit 1)
#nslookup www.baidu.com >/dev/null || (echo "Plese check your dns!" && exit 1)

# Determine OS platform
UNAME=$(uname | tr "[:upper:]" "[:lower:]")
# If Linux, try to determine specific distribution
if [ "$UNAME" = "linux" ]; then
    # If available, use LSB to identify distribution
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        distro=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
    # Otherwise, use release info file
    else
        distro=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
   fi
fi
# For everything else (or if above failed), just use generic identifier
[ "$distro" = "" ] && distro=$UNAME
unset UNAME

# set user id
if [ $1 ];then
    uid=$1
else
    uid="2"
fi
    
# set device name
if [ $2 ];then
    hname=$2
else
    hname=`ip -4 route get 114.114.114.114 | awk {'print $7'} | tr -d '\n'`
fi

minstall(){
    # set hugepage and memlock
    grep -q -F '* soft memlock 262144' /etc/security/limits.conf || echo '* soft memlock 262144' >> /etc/security/limits.conf
    grep -q -F '* hard memlock 262144' /etc/security/limits.conf || echo '* hard memlock 262144' >> /etc/security/limits.conf
    grep -q -F 'vm.nr_hugepages = 256' /etc/sysctl.conf || echo 'vm.nr_hugepages = 256' >> /etc/sysctl.conf
	set +e
    sysctl -w vm.nr_hugepages=256
	set -e

    #apt-get -y install libhwloc4
    wget http://www.yiluzhuanqian.com/soft/linux/yilu_centos6.tgz -O /opt/yilu.tgz
    tar zxf /opt/yilu.tgz -C /opt/

    /opt/yilu/mservice -user_id $uid -reg_device -dev_name $hname

    # uninstall old service
    set +e
    /opt/yilu/mservice -service uninstall

    # install new service
    /opt/yilu/mservice -service install

    # give priority to make money
    sed -i 's/"cpu_priority": 1/"cpu_priority": 34/g' /opt/yilu/work/workers.json
}

if [[ "${distro,,}" = *"ubuntu"* ]] || [[ "${distro,,}" = *"debian"* ]];then
    set +e
    apt-get -y update
    apt-get -y install wget cron sudo
    set -e
    minstall
    # start
    service YiluzhuanqianSer restart
    # start with system boot
    sudo crontab -l -u root 2>/dev/null | grep -q -F 'service YiluzhuanqianSer start' || (sudo crontab -l -u root 2>/dev/null;echo "* * * * * pidof mservice || service YiluzhuanqianSer start") | sudo crontab -u root -
elif [[ "${distro,,}" = *"centos"* ]] || [[ "${distro,,}" = *"redhat"* ]];then
    set +e
    yum -y update
    yum -y install wget crontab sudo
    set -e
    osversion=`grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release`
    if [[ "$osversion" = "7"* ]];then
        minstall
        # start
        service YiluzhuanqianSer restart
        # start with system boot
        sudo crontab -l -u root 2>/dev/null | grep -q -F 'service YiluzhuanqianSer start' || (sudo crontab -l -u root 2>/dev/null;echo "* * * * * pidof mservice || service YiluzhuanqianSer start") | sudo crontab -u root -
    elif [[ "$osversion" = "6"* ]];then
        minstall
        # start
        sudo pidof mservice | xargs kill -9 2>/dev/null
	nohup /opt/yilu/mservice > /dev/null 2>&1 &
        # start with system boot
        sudo crontab -l -u root 2>/dev/null | grep -q -F 'service YiluzhuanqianSer start' || (sudo crontab -l -u root 2>/dev/null;echo "* * * * * pidof mservice || nohup /opt/yilu/mservice > /dev/null 2>&1 &") | sudo crontab -u root -
    fi
else
    echo $distro
    echo "This system is not supported!" && exit 1
fi

sleep 10
tail  /opt/yilu/work/xig/debug.log  -n 100
