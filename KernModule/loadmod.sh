#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
# 
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

MI_D_PATH=/root/mi-d
ROOT_PATH=${MI_D_PATH}/modules

function getdepends()
{
  _moddir="/lib/modules/`/bin/uname -r`"; [ ! -d "${_moddir}" ] && mkdir -p "${_moddir}" && ${MI_D_PATH}/busybox depmod
  echo `${MI_D_PATH}/busybox modinfo ${1} | grep depends: | awk -F: '{print $2}' | awk '$1=$1' | ${MI_D_PATH}/busybox sed 's/,/ /g'`
}


function installmod()
{
  echo "[I] >> ${1}.ko"

  if [ `/sbin/lsmod | grep -i ${1//-/_} | wc -l` -gt 0 ]; then
    echo "[I] Module ${1} File exists"
  else
    KO_PATH=''
    if [ -f "${ROOT_PATH}/${1}.ko" ]; then
      KO_PATH="${ROOT_PATH}/${1}.ko"
    elif [ -f "/lib/modules/${1}.ko" ]; then
      KO_PATH="/lib/modules/${1}.ko"
    elif [ -f "/usr/lib/modules/${1}.ko" ]; then
      KO_PATH="/usr/lib/modules/${1}.ko"
    fi
    
    if [ -f "${KO_PATH}" ]; then
      depends=(`getdepends "${KO_PATH}"`)
      if [ ${#depends[*]} > 0 ]; then
          for k in ${depends[@]}
          do 
              installmod ${k}
          done
      fi
      insmod ${KO_PATH}
      if [ `/sbin/lsmod | grep -i ${1//-/_} | wc -l` -gt 0 ]; then
        echo "[I] Module ${1} loaded succesfully"
      else
        echo "[E] Module ${1} is not loaded"
        exit 2
      fi
    else
      echo "[E] Module ${1} not exists"
      exit 1
    fi
  fi
}

sleeseconds=0
function ipconfigup()
{
  net=`ls -ld /sys/class/net/*/device/driver | grep ${1}`
  if [ -n "${net}" ]; then
    net=`echo "${net}" | ${MI_D_PATH}/busybox sed -r 's|.*/sys/class/net/(.*)/device/driver.*|\1|'`
  fi
  if [ -n "${net}" ]; then
    counts=`ls -ld /sys/class/net/*/device | wc -l`
    ${MI_D_PATH}/busybox sed -i "s/^maxlanport=.*$/maxlanport=\"${counts}\"/g" /etc/synoinfo.conf /etc.defaults/synoinfo.conf

    net=(${net})
    echo "[I] The network card ${net[*]} using driver ${1}, to up."
    for i in ${net[@]}
    do
      echo "[I] up ${i}"
      if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${i}" ]; then
        if [ -f "${MI_D_PATH}/etc/sysconfig/network-scripts/ifcfg-${i}" ]; then
          cp ${MI_D_PATH}/etc/sysconfig/network-scripts/ifcfg-${i} /etc/sysconfig/network-scripts/
        else
          echo -e "DEVICE=${i}\nBOOTPROTO=dhcp\nONBOOT=yes\nIPV6INIT=dhcp\nIPV6_ACCEPT_RA=1\nPRIMARY=${i}\nTYPE=OVS" > "/etc/sysconfig/network-scripts/ifcfg-${i}"
        fi
      fi
      ifconfig ${i} up
      source /etc/sysconfig/network-scripts/ifcfg-${i}
      if [ "$BOOTPROTO" = "dhcp" ]; then
        synonet --dhcp ${i} || true
      elif [[ -v IPADDR && -v NETMASK ]]; then
        ifconfig ${i} inet ${IPADDR} netmask ${NETMASK}
        netstat -nr
      fi

      ovs=1
      [ ! -f '/usr/syno/etc/synoovs/ovs_reg.conf' ] && ovs=0 || [ `cat /usr/syno/etc/synoovs/ovs_reg.conf | wc -l` -eq 0 ] && ovs=0
      if [ ${ovs} -eq 1 ]; then
        echo "[I] up ovs_${i}"
        if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-ovs_${i}" ]; then
          if [ -f "${MI_D_PATH}/etc/sysconfig/network-scripts/ifcfg-ovs_${i}" ]; then
            cp ${MI_D_PATH}/etc/sysconfig/network-scripts/ifcfg-ovs_${i} /etc/sysconfig/network-scripts/
          else
            echo -e "DEVICE=ovs_${i}\nBOOTPROTO=dhcp\nONBOOT=yes\nIPV6INIT=dhcp\nIPV6_ACCEPT_RA=1\nPRIMARY=${i}\nTYPE=OVS" > "/etc/sysconfig/network-scripts/ifcfg-ovs_${i}"
          fi
          ovs-vsctl add-br ovs_${i}
          ovs-vsctl add-port ovs_${i} ${i}
        fi
        ifconfig ovs_${i} up
        source /etc/sysconfig/network-scripts/ifcfg-ovs_${i}
        if [ "$BOOTPROTO" = "dhcp" ]; then
          synonet --dhcp ovs_${i} || true
        elif [[ -v IPADDR && -v NETMASK ]]; then
          ifconfig ovs_${i} inet ${IPADDR} netmask ${NETMASK}
          netstat -nr
        fi
      fi
    done
  else
    if [ ${sleeseconds} -le ${2:-0} ]; then
      let sleeseconds++
      sleep 1s
      ipconfigup $@
    else
      echo "[I] No network card using driver ${1} was found"
    fi
  fi
}

if [ ! -d "${MI_D_PATH}" ]; then
  echo "[E] tools not exists"
  exit 1
fi

echo "[I] load ${1} ..."
installmod ${1}
ipconfigup ${1} 5

exit 0