#!/bin/bash
#

# setup root login
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config

# change root password
echo root:test123 | chpasswd

# get all nic name for operation system, configure the one of Nic name
function get_first_nic_name() {
#!/bin/bash
nic_names=$(ls /sys/class/net/ | grep -v "`ls /sys/devices/virtual/net/`")
new_nic_names=()
short_nic=${nic_names[0]}
for i in ${nic_names[*]};do
    if [ ${#short_nic} -ge  ${#i} ]; then
        short_nic=${i}
    else
        continue
    fi
done

for i in ${nic_names[*]};do
    if [ ${#short_nic} -eq  ${#i} ];then
        new_nic_names[${#new_nic_names[*]}]=${i}
    else
        continue
    fi
done

nic_name=$(echo ${new_nic_names[*]} | tr ' ' '\n' | sort -n | head -1)
sed -i "s/    ens136/    ${nic_name}/g" /etc/netplan/00-installer-config.yaml
}

get_first_nic_name

# setup Number of file handles
tee -a /etc/security/limits.conf << EOF
#
# setup Number of file handles
* soft nofile 204800
* hard nofile 204800
* soft nproc 204800
* hard nproc 204800
EOF

# Enable serial console on Ubuntu
# GRUB_SERIAL_COMMAND="serial --speed=9600" or GRUB_SERIAL_COMMAND="serial --speed=9600 --unit=0 --word=8 --parity=no --stop=1"
sed -i 's/^#\?GRUB_TERMINAL=.*/GRUB_TERMINAL=serial/g' /etc/default/grub
#sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,9600"/g' /etc/default/grub
grep "GRUB_SERIAL_COMMAND" /etc/default/grub > /dev/null 2>&1 || sed -i '/GRUB_CMDLINE_LINUX=.*/a\GRUB_SERIAL_COMMAND="serial --speed=9600"' /etc/default/grub
#update grup
update-grub

sed -i 's/^#\?DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=3s/g' /etc/systemd/system.conf
sed -i 's/^#\?DefaultTimeoutStartSec=.*/DefaultTimeoutStartSec=3s/g' /etc/systemd/system.conf
systemctl daemon-reload

# Location of template file
template_file="/opt/template.xml"

# add cpu number for template file
cpu_number=$(cat /proc/cpuinfo |grep "physical id"|sort |uniq|wc -l)
sed -i "s/cpu_num/${cpu_number}/g" ${template_file}

# add member size for template file
mem_total=$(grep MemTotal /proc/meminfo | awk  '{print $2}')
free_size=$((${mem_total}-638812))
sed -i "s/free_mem/${free_size}/g" ${template_file}

# add network interface card for template file
#nic_list=$(cat /proc/net/dev | awk '{i++; if(i>2){print $1}}' | sed 's/^[\t]*//g' | sed 's/[:]*$//g' | grep -v "lo" | sort -n | grep -v "macvtap")
# get all of the physical nic names
nic_list=$(ls /sys/class/net/ | grep -v "`ls /sys/devices/virtual/net/`")
j=-1
# shellcheck disable=SC2068
for i in ${nic_list[@]}; do
  j=$(expr $j + 1)
  nic_str_constant="nic_${j}_str"
	# to change the mac address from template file
	grep ${nic_str_constant}  ${template_file}
	if [ $? -eq 0 ];then
	    sed -i "s/${nic_str_constant}/${i}/g" ${template_file}
	else
	    break
	fi
done

# local service
img="ECV-8.3.3.5_86013.qcow2"
mv /opt/service/img/${img} /var/lib/libvirt/images/
chmod 755 /var/lib/libvirt/images/${img}
mv /opt/service/bin/getsn  /usr/local/bin
chmod +x /usr/local/bin/getsn || true
rm -rf /opt/service