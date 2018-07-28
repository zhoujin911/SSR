#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR server
#	Version: 2.0.38
#	Author: Toyo
#	Blog: https://doub.io/ss-jc42/
#=================================================

sh_ver="2.0.38"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
ssr_folder="/usr/local/shadowsocksr"
ssr_ss_file="${ssr_folder}/shadowsocks"
config_file="${ssr_folder}/config.json"
config_folder="/etc/shadowsocksr"
config_user_file="${config_folder}/user-config.json"
ssr_log_file="${ssr_ss_file}/ssserver.log"
Libsodiumr_file="/usr/local/lib/libsodium.so"
Libsodiumr_ver_backup="1.0.13"
Server_Speeder_file="/serverspeeder/bin/serverSpeeder.sh"
LotServer_file="/appex/bin/serverSpeeder.sh"
BBR_file="${file}/bbr.sh"
jq_file="${ssr_folder}/jq"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[��Ϣ]${Font_color_suffix}"
Error="${Red_font_prefix}[����]${Font_color_suffix}"
Tip="${Green_font_prefix}[ע��]${Font_color_suffix}"
Separator_1="������������������������������������������������������������"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} ��ǰ�˺ŷ�ROOT(��û��ROOTȨ��)���޷�������������ʹ��${Green_background_prefix} sudo su ${Font_color_suffix}����ȡ��ʱROOTȨ�ޣ�ִ�к����ʾ���뵱ǰ�˺ŵ����룩��" && exit 1
}
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
SSR_installation_status(){
	[[ ! -e ${config_user_file} ]] && echo -e "${Error} û�з��� ShadowsocksR �����ļ������� !" && exit 1
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} û�з��� ShadowsocksR �ļ��У����� !" && exit 1
}
Server_Speeder_installation_status(){
	[[ ! -e ${Server_Speeder_file} ]] && echo -e "${Error} û�а�װ ����(Server Speeder)������ !" && exit 1
}
LotServer_installation_status(){
	[[ ! -e ${LotServer_file} ]] && echo -e "${Error} û�а�װ LotServer������ !" && exit 1
}
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} û�з��� BBR�ű�����ʼ����..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh; then
			echo -e "${Error} BBR �ű�����ʧ�� !" && exit 1
		else
			echo -e "${Info} BBR �ű�������� !"
			chmod +x bbr.sh
		fi
	fi
}
# ���� ����ǽ����
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
# ��ȡ ������Ϣ
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Get_User(){
	[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ������ �����ڣ����� !" && exit 1
	port=`${jq_file} '.server_port' ${config_user_file}`
	password=`${jq_file} '.password' ${config_user_file} | sed 's/^.//;s/.$//'`
	method=`${jq_file} '.method' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol=`${jq_file} '.protocol' ${config_user_file} | sed 's/^.//;s/.$//'`
	obfs=`${jq_file} '.obfs' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol_param=`${jq_file} '.protocol_param' ${config_user_file} | sed 's/^.//;s/.$//'`
	speed_limit_per_con=`${jq_file} '.speed_limit_per_con' ${config_user_file}`
	speed_limit_per_user=`${jq_file} '.speed_limit_per_user' ${config_user_file}`
	connect_verbose_info=`${jq_file} '.connect_verbose_info' ${config_user_file}`
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
ss_link_qr(){
	SSbase64=$(urlsafe_base64 "${method}:${password}@${ip}:${port}")
	SSurl="ss://${SSbase64}"
	SSQRcode="http://doub.pw/qr/qr.php?text=${SSurl}"
	ss_link=" SS    ���� : ${Green_font_prefix}${SSurl}${Font_color_suffix} \n SS  ��ά�� : ${Green_font_prefix}${SSQRcode}${Font_color_suffix}"
}
ssr_link_qr(){
	SSRprotocol=$(echo ${protocol} | sed 's/_compatible//g')
	SSRobfs=$(echo ${obfs} | sed 's/_compatible//g')
	SSRPWDbase64=$(urlsafe_base64 "${password}")
	SSRbase64=$(urlsafe_base64 "${ip}:${port}:${SSRprotocol}:${method}:${SSRobfs}:${SSRPWDbase64}")
	SSRurl="ssr://${SSRbase64}"
	SSRQRcode="http://doub.pw/qr/qr.php?text=${SSRurl}"
	ssr_link=" SSR   ���� : ${Red_font_prefix}${SSRurl}${Font_color_suffix} \n SSR ��ά�� : ${Red_font_prefix}${SSRQRcode}${Font_color_suffix} \n "
}
ss_ssr_determine(){
	protocol_suffix=`echo ${protocol} | awk -F "_" '{print $NF}'`
	obfs_suffix=`echo ${obfs} | awk -F "_" '{print $NF}'`
	if [[ ${protocol} = "origin" ]]; then
		if [[ ${obfs} = "plain" ]]; then
			ss_link_qr
			ssr_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				ss_link=""
			else
				ss_link_qr
			fi
		fi
	else
		if [[ ${protocol_suffix} != "compatible" ]]; then
			ss_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				if [[ ${obfs_suffix} = "plain" ]]; then
					ss_link_qr
				else
					ss_link=""
				fi
			else
				ss_link_qr
			fi
		fi
	fi
	ssr_link_qr
}
# ��ʾ ������Ϣ
View_User(){
	SSR_installation_status
	Get_IP
	Get_User
	now_mode=$(cat "${config_user_file}"|grep '"port_password"')
	[[ -z ${protocol_param} ]] && protocol_param="0(����)"
	if [[ -z "${now_mode}" ]]; then
		ss_ssr_determine
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR�˺� ������Ϣ��" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e " �˿�\t    : ${Green_font_prefix}${port}${Font_color_suffix}"
		echo -e " ����\t    : ${Green_font_prefix}${password}${Font_color_suffix}"
		echo -e " ����\t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e " Э��\t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e " ����\t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e " �豸������ : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e " ���߳����� : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e " �˿������� : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}"
		echo -e "${ss_link}"
		echo -e "${ssr_link}"
		echo -e " ${Green_font_prefix} ��ʾ: ${Font_color_suffix}
 ��������У��򿪶�ά�����ӣ��Ϳ��Կ�����ά��ͼƬ��
 Э��ͻ��������[ _compatible ]��ָ���� ����ԭ��Э��/������"
		echo && echo "==================================================="
	else
		user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
		[[ ${user_total} = "0" ]] && echo -e "${Error} û�з��� ��˿��û������� !" && exit 1
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR�˺� ������Ϣ��" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e " ����\t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e " Э��\t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e " ����\t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e " �豸������ : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e " ���߳����� : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e " �˿������� : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}" && echo
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
			password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
			ss_ssr_determine
			echo -e ${Separator_1}
			echo -e " �˿�\t    : ${Green_font_prefix}${port}${Font_color_suffix}"
			echo -e " ����\t    : ${Green_font_prefix}${password}${Font_color_suffix}"
			echo -e "${ss_link}"
			echo -e "${ssr_link}"
		done
		echo -e " ${Green_font_prefix} ��ʾ: ${Font_color_suffix}
 ��������У��򿪶�ά�����ӣ��Ϳ��Կ�����ά��ͼƬ��
 Э��ͻ��������[ _compatible ]��ָ���� ����ԭ��Э��/������"
		echo && echo "==================================================="
	fi
}
# ���� ������Ϣ
Set_config_port(){
	while true
	do
	echo -e "������Ҫ���õ�ShadowsocksR�˺� �˿�"
	stty erase '^H' && read -p "(Ĭ��: 2333):" ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="2333"
	expr ${ssr_port} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_port} -ge 1 ]] && [[ ${ssr_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	�˿� : ${Green_font_prefix}${ssr_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-65535)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-65535)"
	fi
	done
}
Set_config_password(){
	echo "������Ҫ���õ�ShadowsocksR�˺� ����"
	stty erase '^H' && read -p "(Ĭ��: doub.io):" ssr_password
	[[ -z "${ssr_password}" ]] && ssr_password="doub.io"
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_method(){
	echo -e "��ѡ��Ҫ���õ�ShadowsocksR�˺� ���ܷ�ʽ
	
 ${Green_font_prefix} 1.${Font_color_suffix} none
 ${Tip} ���ʹ�� auth_chain_a Э�飬����ܷ�ʽѡ�� none����������(���� plain)
 
 ${Green_font_prefix} 2.${Font_color_suffix} rc4
 ${Green_font_prefix} 3.${Font_color_suffix} rc4-md5
 ${Green_font_prefix} 4.${Font_color_suffix} rc4-md5-6
 
 ${Green_font_prefix} 5.${Font_color_suffix} aes-128-ctr
 ${Green_font_prefix} 6.${Font_color_suffix} aes-192-ctr
 ${Green_font_prefix} 7.${Font_color_suffix} aes-256-ctr
 
 ${Green_font_prefix} 8.${Font_color_suffix} aes-128-cfb
 ${Green_font_prefix} 9.${Font_color_suffix} aes-192-cfb
 ${Green_font_prefix}10.${Font_color_suffix} aes-256-cfb
 
 ${Green_font_prefix}11.${Font_color_suffix} aes-128-cfb8
 ${Green_font_prefix}12.${Font_color_suffix} aes-192-cfb8
 ${Green_font_prefix}13.${Font_color_suffix} aes-256-cfb8
 
 ${Green_font_prefix}14.${Font_color_suffix} salsa20
 ${Green_font_prefix}15.${Font_color_suffix} chacha20
 ${Green_font_prefix}16.${Font_color_suffix} chacha20-ietf
 ${Tip} salsa20/chacha20-*ϵ�м��ܷ�ʽ����Ҫ���ⰲװ���� libsodium ��������޷�����ShadowsocksR !" && echo
	stty erase '^H' && read -p "(Ĭ��: 5. aes-128-ctr):" ssr_method
	[[ -z "${ssr_method}" ]] && ssr_method="5"
	if [[ ${ssr_method} == "1" ]]; then
		ssr_method="none"
	elif [[ ${ssr_method} == "2" ]]; then
		ssr_method="rc4"
	elif [[ ${ssr_method} == "3" ]]; then
		ssr_method="rc4-md5"
	elif [[ ${ssr_method} == "4" ]]; then
		ssr_method="rc4-md5-6"
	elif [[ ${ssr_method} == "5" ]]; then
		ssr_method="aes-128-ctr"
	elif [[ ${ssr_method} == "6" ]]; then
		ssr_method="aes-192-ctr"
	elif [[ ${ssr_method} == "7" ]]; then
		ssr_method="aes-256-ctr"
	elif [[ ${ssr_method} == "8" ]]; then
		ssr_method="aes-128-cfb"
	elif [[ ${ssr_method} == "9" ]]; then
		ssr_method="aes-192-cfb"
	elif [[ ${ssr_method} == "10" ]]; then
		ssr_method="aes-256-cfb"
	elif [[ ${ssr_method} == "11" ]]; then
		ssr_method="aes-128-cfb8"
	elif [[ ${ssr_method} == "12" ]]; then
		ssr_method="aes-192-cfb8"
	elif [[ ${ssr_method} == "13" ]]; then
		ssr_method="aes-256-cfb8"
	elif [[ ${ssr_method} == "14" ]]; then
		ssr_method="salsa20"
	elif [[ ${ssr_method} == "15" ]]; then
		ssr_method="chacha20"
	elif [[ ${ssr_method} == "16" ]]; then
		ssr_method="chacha20-ietf"
	else
		ssr_method="aes-128-ctr"
	fi
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_method}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_protocol(){
	echo -e "��ѡ��Ҫ���õ�ShadowsocksR�˺� Э����
	
 ${Green_font_prefix}1.${Font_color_suffix} origin
 ${Green_font_prefix}2.${Font_color_suffix} auth_sha1_v4
 ${Green_font_prefix}3.${Font_color_suffix} auth_aes128_md5
 ${Green_font_prefix}4.${Font_color_suffix} auth_aes128_sha1
 ${Green_font_prefix}5.${Font_color_suffix} auth_chain_a
 ${Green_font_prefix}6.${Font_color_suffix} auth_chain_b
 ${Tip} ���ʹ�� auth_chain_a Э�飬����ܷ�ʽѡ�� none����������(���� plain)" && echo
	stty erase '^H' && read -p "(Ĭ��: 2. auth_sha1_v4):" ssr_protocol
	[[ -z "${ssr_protocol}" ]] && ssr_protocol="2"
	if [[ ${ssr_protocol} == "1" ]]; then
		ssr_protocol="origin"
	elif [[ ${ssr_protocol} == "2" ]]; then
		ssr_protocol="auth_sha1_v4"
	elif [[ ${ssr_protocol} == "3" ]]; then
		ssr_protocol="auth_aes128_md5"
	elif [[ ${ssr_protocol} == "4" ]]; then
		ssr_protocol="auth_aes128_sha1"
	elif [[ ${ssr_protocol} == "5" ]]; then
		ssr_protocol="auth_chain_a"
	elif [[ ${ssr_protocol} == "6" ]]; then
		ssr_protocol="auth_chain_b"
	else
		ssr_protocol="auth_sha1_v4"
	fi
	echo && echo ${Separator_1} && echo -e "	Э�� : ${Green_font_prefix}${ssr_protocol}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_protocol} != "origin" ]]; then
		if [[ ${ssr_protocol} == "auth_sha1_v4" ]]; then
			stty erase '^H' && read -p "�Ƿ����� Э��������ԭ��(_compatible)��[Y/n]" ssr_protocol_yn
			[[ -z "${ssr_protocol_yn}" ]] && ssr_protocol_yn="y"
			[[ $ssr_protocol_yn == [Yy] ]] && ssr_protocol=${ssr_protocol}"_compatible"
			echo
		fi
	fi
}
Set_config_obfs(){
	echo -e "��ѡ��Ҫ���õ�ShadowsocksR�˺� �������
	
 ${Green_font_prefix}1.${Font_color_suffix} plain
 ${Green_font_prefix}2.${Font_color_suffix} http_simple
 ${Green_font_prefix}3.${Font_color_suffix} http_post
 ${Green_font_prefix}4.${Font_color_suffix} random_head
 ${Green_font_prefix}5.${Font_color_suffix} tls1.2_ticket_auth
 ${Tip} ���ʹ�� ShadowsocksR ������Ϸ����ѡ�� ��������ԭ��� plain ������Ȼ��ͻ���ѡ�� plain������������ӳ� !" && echo
	stty erase '^H' && read -p "(Ĭ��: 5. tls1.2_ticket_auth):" ssr_obfs
	[[ -z "${ssr_obfs}" ]] && ssr_obfs="5"
	if [[ ${ssr_obfs} == "1" ]]; then
		ssr_obfs="plain"
	elif [[ ${ssr_obfs} == "2" ]]; then
		ssr_obfs="http_simple"
	elif [[ ${ssr_obfs} == "3" ]]; then
		ssr_obfs="http_post"
	elif [[ ${ssr_obfs} == "4" ]]; then
		ssr_obfs="random_head"
	elif [[ ${ssr_obfs} == "5" ]]; then
		ssr_obfs="tls1.2_ticket_auth"
	else
		ssr_obfs="tls1.2_ticket_auth"
	fi
	echo && echo ${Separator_1} && echo -e "	���� : ${Green_font_prefix}${ssr_obfs}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_obfs} != "plain" ]]; then
			stty erase '^H' && read -p "�Ƿ����� �����������ԭ��(_compatible)��[Y/n]" ssr_obfs_yn
			[[ -z "${ssr_obfs_yn}" ]] && ssr_obfs_yn="y"
			[[ $ssr_obfs_yn == [Yy] ]] && ssr_obfs=${ssr_obfs}"_compatible"
			echo
	fi
}
Set_config_protocol_param(){
	while true
	do
	echo -e "������Ҫ���õ�ShadowsocksR�˺� �����Ƶ��豸�� (${Green_font_prefix} auth_* ϵ��Э�� ������ԭ�����Ч ${Font_color_suffix})"
	echo -e "${Tip} �豸�����ƣ�ÿ���˿�ͬһʱ�������ӵĿͻ�������(��˿�ģʽ��ÿ���˿ڶ��Ƕ�������)���������� 2����"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_protocol_param
	[[ -z "$ssr_protocol_param" ]] && ssr_protocol_param="" && echo && break
	expr ${ssr_protocol_param} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_protocol_param} -ge 1 ]] && [[ ${ssr_protocol_param} -le 9999 ]]; then
			echo && echo ${Separator_1} && echo -e "	�豸������ : ${Green_font_prefix}${ssr_protocol_param}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-9999)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-9999)"
	fi
	done
}
Set_config_speed_limit_per_con(){
	while true
	do
	echo -e "������Ҫ���õ�ÿ���˿� ���߳� ��������(��λ��KB/S)"
	echo -e "${Tip} ���߳����٣�ÿ���˿� ���̵߳��������ޣ����̼߳���Ч��"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_speed_limit_per_con
	[[ -z "$ssr_speed_limit_per_con" ]] && ssr_speed_limit_per_con=0 && echo && break
	expr ${ssr_speed_limit_per_con} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_con} -ge 1 ]] && [[ ${ssr_speed_limit_per_con} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	���߳����� : ${Green_font_prefix}${ssr_speed_limit_per_con} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-131072)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-131072)"
	fi
	done
}
Set_config_speed_limit_per_user(){
	while true
	do
	echo
	echo -e "������Ҫ���õ�ÿ���˿� ���ٶ� ��������(��λ��KB/S)"
	echo -e "${Tip} �˿������٣�ÿ���˿� ���ٶ� �������ޣ������˿��������١�"
	stty erase '^H' && read -p "(Ĭ��: ����):" ssr_speed_limit_per_user
	[[ -z "$ssr_speed_limit_per_user" ]] && ssr_speed_limit_per_user=0 && echo && break
	expr ${ssr_speed_limit_per_user} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_user} -ge 1 ]] && [[ ${ssr_speed_limit_per_user} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	�˿������� : ${Green_font_prefix}${ssr_speed_limit_per_user} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} ��������ȷ������(1-131072)"
		fi
	else
		echo -e "${Error} ��������ȷ������(1-131072)"
	fi
	done
}
Set_config_all(){
	Set_config_port
	Set_config_password
	Set_config_method
	Set_config_protocol
	Set_config_obfs
	Set_config_protocol_param
	Set_config_speed_limit_per_con
	Set_config_speed_limit_per_user
}
# �޸� ������Ϣ
Modify_config_port(){
	sed -i 's/"server_port": '"$(echo ${port})"'/"server_port": '"$(echo ${ssr_port})"'/g' ${config_user_file}
}
Modify_config_password(){
	sed -i 's/"password": "'"$(echo ${password})"'"/"password": "'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
Modify_config_method(){
	sed -i 's/"method": "'"$(echo ${method})"'"/"method": "'"$(echo ${ssr_method})"'"/g' ${config_user_file}
}
Modify_config_protocol(){
	sed -i 's/"protocol": "'"$(echo ${protocol})"'"/"protocol": "'"$(echo ${ssr_protocol})"'"/g' ${config_user_file}
}
Modify_config_obfs(){
	sed -i 's/"obfs": "'"$(echo ${obfs})"'"/"obfs": "'"$(echo ${ssr_obfs})"'"/g' ${config_user_file}
}
Modify_config_protocol_param(){
	sed -i 's/"protocol_param": "'"$(echo ${protocol_param})"'"/"protocol_param": "'"$(echo ${ssr_protocol_param})"'"/g' ${config_user_file}
}
Modify_config_speed_limit_per_con(){
	sed -i 's/"speed_limit_per_con": '"$(echo ${speed_limit_per_con})"'/"speed_limit_per_con": '"$(echo ${ssr_speed_limit_per_con})"'/g' ${config_user_file}
}
Modify_config_speed_limit_per_user(){
	sed -i 's/"speed_limit_per_user": '"$(echo ${speed_limit_per_user})"'/"speed_limit_per_user": '"$(echo ${ssr_speed_limit_per_user})"'/g' ${config_user_file}
}
Modify_config_connect_verbose_info(){
	sed -i 's/"connect_verbose_info": '"$(echo ${connect_verbose_info})"'/"connect_verbose_info": '"$(echo ${ssr_connect_verbose_info})"'/g' ${config_user_file}
}
Modify_config_all(){
	Modify_config_port
	Modify_config_password
	Modify_config_method
	Modify_config_protocol
	Modify_config_obfs
	Modify_config_protocol_param
	Modify_config_speed_limit_per_con
	Modify_config_speed_limit_per_user
}
Modify_config_port_many(){
	sed -i 's/"'"$(echo ${port})"'":/"'"$(echo ${ssr_port})"'":/g' ${config_user_file}
}
Modify_config_password_many(){
	sed -i 's/"'"$(echo ${password})"'"/"'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
# д�� ������Ϣ
Write_configuration(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${ssr_port},
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "password": "${ssr_password}",
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Write_configuration_many(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "port_password":{
        "${ssr_port}":"${ssr_password}"
    },
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} û�а�װPython����ʼ��װ..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python
		else
			apt-get install -y python
		fi
	fi
}
Centos_yum(){
	yum update
	cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
	if [[ $? = 0 ]]; then
		yum install -y vim unzip net-tools
	else
		yum install -y vim unzip
	fi
}
Debian_apt(){
	apt-get update
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y vim unzip net-tools
	else
		apt-get install -y vim unzip
	fi
}
# ���� ShadowsocksR
Download_SSR(){
	cd "/usr/local/"
	wget -N --no-check-certificate "https://github.com/ToyoDAdoubi/shadowsocksr/archive/manyuser.zip"
	#git config --global http.sslVerify false
	#env GIT_SSL_NO_VERIFY=true git clone -b manyuser https://github.com/ToyoDAdoubi/shadowsocksr.git
	#[[ ! -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR����� ����ʧ�� !" && exit 1
	[[ ! -e "manyuser.zip" ]] && echo -e "${Error} ShadowsocksR����� ѹ���� ����ʧ�� !" && rm -rf manyuser.zip && exit 1
	unzip "manyuser.zip"
	[[ ! -e "/usr/local/shadowsocksr-manyuser/" ]] && echo -e "${Error} ShadowsocksR����� ��ѹʧ�� !" && rm -rf manyuser.zip && exit 1
	mv "/usr/local/shadowsocksr-manyuser/" "/usr/local/shadowsocksr/"
	[[ ! -e "/usr/local/shadowsocksr/" ]] && echo -e "${Error} ShadowsocksR����� ������ʧ�� !" && rm -rf manyuser.zip && rm -rf "/usr/local/shadowsocksr-manyuser/" && exit 1
	rm -rf manyuser.zip
	[[ -e ${config_folder} ]] && rm -rf ${config_folder}
	mkdir ${config_folder}
	[[ ! -e ${config_folder} ]] && echo -e "${Error} ShadowsocksR�����ļ����ļ��� ����ʧ�� !" && exit 1
	echo -e "${Info} ShadowsocksR����� ������� !"
}
Service_SSR(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_centos -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR���� ����ű�����ʧ�� !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		chkconfig --add ssr
		chkconfig ssr on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_debian -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR���� ����ű�����ʧ�� !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		update-rc.d -f ssr defaults
	fi
	echo -e "${Info} ShadowsocksR���� ����ű�������� !"
}
# ��װ JQ������
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		cd "${ssr_folder}"
		if [[ ${bit} = "x86_64" ]]; then
			mv "jq-linux64" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" -O ${jq_file}
		else
			mv "jq-linux32" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32" -O ${jq_file}
		fi
		[[ ! -e ${jq_file} ]] && echo -e "${Error} JQ������ ������ʧ�ܣ����� !" && exit 1
		chmod +x ${jq_file}
		echo -e "${Info} JQ������ ��װ��ɣ�����..." 
	else
		echo -e "${Info} JQ������ �Ѱ�װ������..."
	fi
}
# ��װ ����
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	[[ ! -e "/usr/bin/unzip" ]] && echo -e "${Error} ���� unzip(��ѹѹ����) ��װʧ�ܣ�����������Դ�����⣬���� !" && exit 1
	Check_python
	#echo "nameserver 8.8.8.8" > /etc/resolv.conf
	#echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}
Install_SSR(){
	check_root
	[[ -e ${config_user_file} ]] && echo -e "${Error} ShadowsocksR �����ļ��Ѵ��ڣ�����( �簲װʧ�ܻ��ߴ��ھɰ汾������ж�� ) !" && exit 1
	[[ -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR �ļ����Ѵ��ڣ�����( �簲װʧ�ܻ��ߴ��ھɰ汾������ж�� ) !" && exit 1
	echo -e "${Info} ��ʼ���� ShadowsocksR�˺�����..."
	Set_config_all
	echo -e "${Info} ��ʼ��װ/���� ShadowsocksR����..."
	Installation_dependency
	echo -e "${Info} ��ʼ����/��װ ShadowsocksR�ļ�..."
	Download_SSR
	echo -e "${Info} ��ʼ����/��װ ShadowsocksR����ű�(init)..."
	Service_SSR
	echo -e "${Info} ��ʼ����/��װ JSNO������ JQ..."
	JQ_install
	echo -e "${Info} ��ʼд�� ShadowsocksR�����ļ�..."
	Write_configuration
	echo -e "${Info} ��ʼ���� iptables����ǽ..."
	Set_iptables
	echo -e "${Info} ��ʼ��� iptables����ǽ����..."
	Add_iptables
	echo -e "${Info} ��ʼ���� iptables����ǽ����..."
	Save_iptables
	echo -e "${Info} ���в��� ��װ��ϣ���ʼ���� ShadowsocksR�����..."
	Start_SSR
}
Update_SSR(){
	SSR_installation_status
	echo -e "��������ͣ����ShadowsocksR����ˣ����Դ˹�����ʱ���á�"
	#cd ${ssr_folder}
	#git pull
	#Restart_SSR
}
Uninstall_SSR(){
	[[ ! -e ${config_user_file} ]] && [[ ! -e ${ssr_folder} ]] && echo -e "${Error} û�а�װ ShadowsocksR������ !" && exit 1
	echo "ȷ��Ҫ ж��ShadowsocksR��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		if [[ -z "${now_mode}" ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Del_iptables
		else
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
				Del_iptables
			done
		fi
		if [[ ${release} = "centos" ]]; then
			chkconfig --del ssr
		else
			update-rc.d -f ssr remove
		fi
		rm -rf ${ssr_folder} && rm -rf ${config_folder} && rm -rf /etc/init.d/ssr
		echo && echo " ShadowsocksR ж����� !" && echo
	else
		echo && echo " ж����ȡ��..." && echo
	fi
}
Check_Libsodium_ver(){
	echo -e "${Info} ��ʼ��ȡ libsodium ���°汾..."
	Libsodiumr_ver=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
	[[ -z ${Libsodiumr_ver} ]] && Libsodiumr_ver=${Libsodiumr_ver_backup}
	echo -e "${Info} libsodium ���°汾Ϊ ${Green_font_prefix}${Libsodiumr_ver}${Font_color_suffix} !"
}
Install_Libsodium(){
	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Error} libsodium �Ѱ�װ , �Ƿ񸲸ǰ�װ(����)��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" yn
		[[ -z ${yn} ]] && yn="n"
		if [[ ${yn} == [Nn] ]]; then
			echo "��ȡ��..." && exit 1
		fi
	else
		echo -e "${Info} libsodium δ��װ����ʼ��װ..."
	fi
	Check_Libsodium_ver
	if [[ ${release} == "centos" ]]; then
		yum update
		echo -e "${Info} ��װ����..."
		yum -y groupinstall "Development Tools"
		echo -e "${Info} ����..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} ��ѹ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} ���밲װ..."
		./configure --disable-maintainer-mode && make -j2 && make install
		echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	else
		apt-get update
		echo -e "${Info} ��װ����..."
		apt-get install -y build-essential
		echo -e "${Info} ����..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} ��ѹ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} ���밲װ..."
		./configure --disable-maintainer-mode && make -j2 && make install
	fi
	ldconfig
	cd .. && rm -rf libsodium-${Libsodiumr_ver}.tar.gz && rm -rf libsodium-${Libsodiumr_ver}
	[[ ! -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium ��װʧ�� !" && exit 1
	echo && echo -e "${Info} libsodium ��װ�ɹ� !" && echo
}
# ��ʾ ������Ϣ
debian_View_user_connection_info(){
	format_1=$1
	if [[ -z "${now_mode}" ]]; then
		now_mode="���˿�" && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep ":${user_port} " |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" `
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_list_all="�˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
		echo -e "��ǰģʽ: ${Green_background_prefix} "${now_mode}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix}"
		echo -e "${user_list_all}"
	else
		now_mode="��˿�" && user_total=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" |wc -l`
		user_list_all=""
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' |awk -F ":" '{print $1}' |sed -n "${integer}p" |sed -r 's/.*\"(.+)\".*/\1/'`
			user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
			if [[ -z ${user_IP_1} ]]; then
				user_IP_total="0"
			else
				user_IP_total=`echo -e "${user_IP_1}"|wc -l`
				if [[ ${format_1} == "IP_address" ]]; then
					get_IP_address
				else
					user_IP=`echo -e "\n${user_IP_1}"`
				fi
			fi
			user_list_all=${user_list_all}"�˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
			user_IP=""
		done
		echo -e "��ǰģʽ: ${Green_background_prefix} "${now_mode}" ${Font_color_suffix} �û�����: ${Green_background_prefix} "${user_total}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e "${user_list_all}"
	fi
}
centos_View_user_connection_info(){
	format_1=$1
	if [[ -z "${now_mode}" ]]; then
		now_mode="���˿�" && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep ":${user_port} " | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_list_all="�˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
		echo -e "��ǰģʽ: ${Green_background_prefix} "${now_mode}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix}"
		echo -e "${user_list_all}"
	else
		now_mode="��˿�" && user_total=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" |wc -l`
		user_list_all=""
		for((integer = 1; integer <= ${user_total}; integer++))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' |awk -F ":" '{print $1}' |sed -n "${integer}p" |sed -r 's/.*\"(.+)\".*/\1/'`
			user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}"|grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" `
			if [[ -z ${user_IP_1} ]]; then
				user_IP_total="0"
			else
				user_IP_total=`echo -e "${user_IP_1}"|wc -l`
				if [[ ${format_1} == "IP_address" ]]; then
					get_IP_address
				else
					user_IP=`echo -e "\n${user_IP_1}"`
				fi
			fi
			user_list_all=${user_list_all}"�˿�: ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t ����IP����: ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t ��ǰ����IP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
			user_IP=""
		done
		echo -e "��ǰģʽ: ${Green_background_prefix} "${now_mode}" ${Font_color_suffix} �û�����: ${Green_background_prefix} "${user_total}" ${Font_color_suffix} ����IP����: ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e "${user_list_all}"
	fi
}
View_user_connection_info(){
	SSR_installation_status
	echo && echo -e "��ѡ��Ҫ��ʾ�ĸ�ʽ��
 ${Green_font_prefix}1.${Font_color_suffix} ��ʾ IP ��ʽ
 ${Green_font_prefix}2.${Font_color_suffix} ��ʾ IP+IP������ ��ʽ" && echo
	stty erase '^H' && read -p "(Ĭ��: 1):" ssr_connection_info
	[[ -z "${ssr_connection_info}" ]] && ssr_connection_info="1"
	if [[ ${ssr_connection_info} == "1" ]]; then
		View_user_connection_info_1 ""
	elif [[ ${ssr_connection_info} == "2" ]]; then
		echo -e "${Tip} ���IP������(ipip.net)�����IP�϶࣬����ʱ���Ƚϳ�..."
		View_user_connection_info_1 "IP_address"
	else
		echo -e "${Error} ��������ȷ������(1-2)" && exit 1
	fi
}
View_user_connection_info_1(){
	format=$1
	if [[ ${release} = "centos" ]]; then
		cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
		if [[ $? = 0 ]]; then
			debian_View_user_connection_info "$format"
		else
			centos_View_user_connection_info "$format"
		fi
	else
		debian_View_user_connection_info "$format"
	fi
}
get_IP_address(){
	#echo "user_IP_1=${user_IP_1}"
	if [[ ! -z ${user_IP_1} ]]; then
	#echo "user_IP_total=${user_IP_total}"
		for((integer_1 = ${user_IP_total}; integer_1 >= 1; integer_1--))
		do
			IP=`echo "${user_IP_1}" |sed -n "$integer_1"p`
			#echo "IP=${IP}"
			IP_address=`wget -qO- -t1 -T2 http://freeapi.ipip.net/${IP}|sed 's/\"//g;s/,//g;s/\[//g;s/\]//g'`
			#echo "IP_address=${IP_address}"
			user_IP="${user_IP}\n${IP}(${IP_address})"
			#echo "user_IP=${user_IP}"
			sleep 1s
		done
	fi
}
# �޸� �û�����
Modify_Config(){
	SSR_installation_status
	if [[ -z "${now_mode}" ]]; then
		echo && echo -e "��ǰģʽ: ���˿ڣ���Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix} �޸� �û��˿�
 ${Green_font_prefix}2.${Font_color_suffix} �޸� �û�����
 ${Green_font_prefix}3.${Font_color_suffix} �޸� ���ܷ�ʽ
 ${Green_font_prefix}4.${Font_color_suffix} �޸� Э����
 ${Green_font_prefix}5.${Font_color_suffix} �޸� �������
 ${Green_font_prefix}6.${Font_color_suffix} �޸� �豸������
 ${Green_font_prefix}7.${Font_color_suffix} �޸� ���߳�����
 ${Green_font_prefix}8.${Font_color_suffix} �޸� �˿�������
 ${Green_font_prefix}9.${Font_color_suffix} �޸� ȫ������" && echo
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo "��ȡ��..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Set_config_port
			Modify_config_port
			Add_iptables
			Del_iptables
			Save_iptables
		elif [[ ${ssr_modify} == "2" ]]; then
			Set_config_password
			Modify_config_password
		elif [[ ${ssr_modify} == "3" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_all
			Modify_config_all
		else
			echo -e "${Error} ��������ȷ������(1-9)" && exit 1
		fi
	else
		echo && echo -e "��ǰģʽ: ��˿ڣ���Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix}  ��� �û�����
 ${Green_font_prefix}2.${Font_color_suffix}  ɾ�� �û�����
 ${Green_font_prefix}3.${Font_color_suffix}  �޸� �û�����
��������������������
 ${Green_font_prefix}4.${Font_color_suffix}  �޸� ���ܷ�ʽ
 ${Green_font_prefix}5.${Font_color_suffix}  �޸� Э����
 ${Green_font_prefix}6.${Font_color_suffix}  �޸� �������
 ${Green_font_prefix}7.${Font_color_suffix}  �޸� �豸������
 ${Green_font_prefix}8.${Font_color_suffix}  �޸� ���߳�����
 ${Green_font_prefix}9.${Font_color_suffix}  �޸� �˿�������
 ${Green_font_prefix}10.${Font_color_suffix} �޸� ȫ������" && echo
		stty erase '^H' && read -p "(Ĭ��: ȡ��):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo "��ȡ��..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Add_multi_port_user
		elif [[ ${ssr_modify} == "2" ]]; then
			Del_multi_port_user
		elif [[ ${ssr_modify} == "3" ]]; then
			Modify_multi_port_user
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "10" ]]; then
			Set_config_method
			Set_config_protocol
			Set_config_obfs
			Set_config_protocol_param
			Set_config_speed_limit_per_con
			Set_config_speed_limit_per_user
			Modify_config_method
			Modify_config_protocol
			Modify_config_obfs
			Modify_config_protocol_param
			Modify_config_speed_limit_per_con
			Modify_config_speed_limit_per_user
		else
			echo -e "${Error} ��������ȷ������(1-9)" && exit 1
		fi
	fi
	Restart_SSR
}
# ��ʾ ��˿��û�����
List_multi_port_user(){
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ ${user_total} = "0" ]] && echo -e "${Error} û�з��� ��˿��û������� !" && exit 1
	user_list_all=""
	for((integer = ${user_total}; integer >= 1; integer--))
	do
		user_port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
		user_password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
		user_list_all=${user_list_all}"�˿�: "${user_port}" ����: "${user_password}"\n"
	done
	echo && echo -e "�û����� ${Green_font_prefix}"${user_total}"${Font_color_suffix}"
	echo -e ${user_list_all}
}
# ��� ��˿��û�����
Add_multi_port_user(){
	Set_config_port
	Set_config_password
	sed -i "8 i \"        \"${ssr_port}\":\"${ssr_password}\"," ${config_user_file}
	sed -i "8s/^\"//" ${config_user_file}
	Add_iptables
	Save_iptables
	echo -e "${Info} ��˿��û������� ${Green_font_prefix}[�˿�: ${ssr_port} , ����: ${ssr_password}]${Font_color_suffix} "
}
# �޸� ��˿��û�����
Modify_multi_port_user(){
	List_multi_port_user
	echo && echo -e "������Ҫ�޸ĵ��û��˿�"
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" modify_user_port
	[[ -z "${modify_user_port}" ]] && echo -e "��ȡ��..." && exit 1
	del_user=`cat ${config_user_file}|grep '"'"${modify_user_port}"'"'`
	if [[ ! -z "${del_user}" ]]; then
		port="${modify_user_port}"
		password=`echo -e ${del_user}|awk -F ":" '{print $NF}'|sed -r 's/.*\"(.+)\".*/\1/'`
		Set_config_port
		Set_config_password
		sed -i 's/"'$(echo ${port})'":"'$(echo ${password})'"/"'$(echo ${ssr_port})'":"'$(echo ${ssr_password})'"/g' ${config_user_file}
		Del_iptables
		Add_iptables
		Save_iptables
		echo -e "${Inof} ��˿��û��޸���� ${Green_font_prefix}[��: ${modify_user_port}  ${password} , ��: ${ssr_port}  ${ssr_password}]${Font_color_suffix} "
	else
		echo -e "${Error} ��������ȷ�Ķ˿� !" && exit 1
	fi
}
# ɾ�� ��˿��û�����
Del_multi_port_user(){
	List_multi_port_user
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ "${user_total}" = "1" ]] && echo -e "${Error} ��˿��û���ʣ 1��������ɾ�� !" && exit 1
	echo -e "������Ҫɾ�����û��˿�"
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" del_user_port
	[[ -z "${del_user_port}" ]] && echo -e "��ȡ��..." && exit 1
	del_user=`cat ${config_user_file}|grep '"'"${del_user_port}"'"'`
	if [[ ! -z ${del_user} ]]; then
		port=${del_user_port}
		Del_iptables
		Save_iptables
		del_user_determine=`echo ${del_user:((${#del_user} - 1))}`
		if [[ ${del_user_determine} != "," ]]; then
			del_user_num=$(sed -n -e "/${port}/=" ${config_user_file})
			del_user_num=$(expr $del_user_num - 1)
			sed -i "${del_user_num}s/,//g" ${config_user_file}
		fi
		sed -i "/${port}/d" ${config_user_file}
		echo -e "${Info} ��˿��û�ɾ����� ${Green_font_prefix} ${del_user_port} ${Font_color_suffix} "
	else
		echo "${Error} ��������ȷ�Ķ˿� !" && exit 1
	fi
}
# �ֶ��޸� �û�����
Manually_Modify_Config(){
	SSR_installation_status
	port=`${jq_file} '.server_port' ${config_user_file}`
	vi ${config_user_file}
	if [[ -z "${now_mode}" ]]; then
		ssr_port=`${jq_file} '.server_port' ${config_user_file}`
		Del_iptables
		Add_iptables
	fi
	Restart_SSR
}
# �л��˿�ģʽ
Port_mode_switching(){
	SSR_installation_status
	if [[ -z "${now_mode}" ]]; then
		echo && echo -e "	��ǰģʽ: ${Green_font_prefix}���˿�${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ��˿�ģʽ��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Set_config_all
			Write_configuration_many
			Del_iptables
			Add_iptables
			Save_iptables
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo && echo -e "	��ǰģʽ: ${Green_font_prefix}��˿�${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ���˿�ģʽ��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
				Del_iptables
			done
			Set_config_all
			Write_configuration
			Add_iptables
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	fi
}
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR �������� !" && exit 1
	/etc/init.d/ssr start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR δ���� !" && exit 1
	/etc/init.d/ssr stop
}
Restart_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/ssr stop
	/etc/init.d/ssr start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR��־�ļ������� !" && exit 1
	echo && echo -e "${Tip} �� ${Red_font_prefix}Ctrl+C${Font_color_suffix} ��ֹ�鿴��־" && echo
	tail -f ${ssr_log_file}
}
# ����
Configure_Server_Speeder(){
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix} ��װ ����
 ${Green_font_prefix}2.${Font_color_suffix} ж�� ����
����������������
 ${Green_font_prefix}3.${Font_color_suffix} ���� ����
 ${Green_font_prefix}4.${Font_color_suffix} ֹͣ ����
 ${Green_font_prefix}5.${Font_color_suffix} ���� ����
 ${Green_font_prefix}6.${Font_color_suffix} �鿴 ���� ״̬
 
 ע�⣺ ���ٺ�LotServer����ͬʱ��װ/������" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" server_speeder_num
	[[ -z "${server_speeder_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${server_speeder_num} == "1" ]]; then
		Install_ServerSpeeder
	elif [[ ${server_speeder_num} == "2" ]]; then
		Server_Speeder_installation_status
		Uninstall_ServerSpeeder
	elif [[ ${server_speeder_num} == "3" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} start
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "4" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} stop
	elif [[ ${server_speeder_num} == "5" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} restart
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "6" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} status
	else
		echo -e "${Error} ��������ȷ������(1-6)" && exit 1
	fi
}
Install_ServerSpeeder(){
	[[ -e ${Server_Speeder_file} ]] && echo -e "${Error} ����(Server Speeder) �Ѱ�װ !" && exit 1
	cd /root
	#����91yun.rog�Ŀ��İ�����
	wget -N --no-check-certificate https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder.sh
	[[ ! -e "serverspeeder.sh" ]] && echo -e "${Error} ���ٰ�װ�ű�����ʧ�� !" && exit 1
	bash serverspeeder.sh
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "serverspeeder" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		rm -rf /root/serverspeeder.sh
		rm -rf /root/91yunserverspeeder
		rm -rf /root/91yunserverspeeder.tar.gz
		echo -e "${Info} ����(Server Speeder) ��װ��� !" && exit 1
	else
		echo -e "${Error} ����(Server Speeder) ��װʧ�� !" && exit 1
	fi
}
Uninstall_ServerSpeeder(){
	echo "ȷ��Ҫж�� ����(Server Speeder)��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "��ȡ��..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		chattr -i /serverspeeder/etc/apx*
		/serverspeeder/bin/serverSpeeder.sh uninstall -f
		echo && echo "����(Server Speeder) ж����� !" && echo
	fi
}
# LotServer
Configure_LotServer(){
	echo && echo -e "��Ҫ��ʲô��
 ${Green_font_prefix}1.${Font_color_suffix} ��װ LotServer
 ${Green_font_prefix}2.${Font_color_suffix} ж�� LotServer
����������������
 ${Green_font_prefix}3.${Font_color_suffix} ���� LotServer
 ${Green_font_prefix}4.${Font_color_suffix} ֹͣ LotServer
 ${Green_font_prefix}5.${Font_color_suffix} ���� LotServer
 ${Green_font_prefix}6.${Font_color_suffix} �鿴 LotServer ״̬
 
 ע�⣺ ���ٺ�LotServer����ͬʱ��װ/������" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" lotserver_num
	[[ -z "${lotserver_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${lotserver_num} == "1" ]]; then
		Install_LotServer
	elif [[ ${lotserver_num} == "2" ]]; then
		LotServer_installation_status
		Uninstall_LotServer
	elif [[ ${lotserver_num} == "3" ]]; then
		LotServer_installation_status
		${LotServer_file} start
		${LotServer_file} status
	elif [[ ${lotserver_num} == "4" ]]; then
		LotServer_installation_status
		${LotServer_file} stop
	elif [[ ${lotserver_num} == "5" ]]; then
		LotServer_installation_status
		${LotServer_file} restart
		${LotServer_file} status
	elif [[ ${lotserver_num} == "6" ]]; then
		LotServer_installation_status
		${LotServer_file} status
	else
		echo -e "${Error} ��������ȷ������(1-6)" && exit 1
	fi
}
Install_LotServer(){
	[[ -e ${LotServer_file} ]] && echo -e "${Error} LotServer �Ѱ�װ !" && exit 1
	#Github: https://github.com/0oVicero0/serverSpeeder_Install
	wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh"
	[[ ! -e "/tmp/appex.sh" ]] && echo -e "${Error} LotServer ��װ�ű�����ʧ�� !" && exit 1
	bash /tmp/appex.sh 'install'
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "appex" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		echo -e "${Info} LotServer ��װ��� !" && exit 1
	else
		echo -e "${Error} LotServer ��װʧ�� !" && exit 1
	fi
}
Uninstall_LotServer(){
	echo "ȷ��Ҫж�� LotServer��[y/N]" && echo
	stty erase '^H' && read -p "(Ĭ��: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "��ȡ��..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh" && bash /tmp/appex.sh 'uninstall'
		echo && echo "LotServer ж����� !" && echo
	fi
}
# BBR
Configure_BBR(){
	echo && echo -e "  ��Ҫ��ʲô��
	
 ${Green_font_prefix}1.${Font_color_suffix} ��װ BBR
����������������
 ${Green_font_prefix}2.${Font_color_suffix} ���� BBR
 ${Green_font_prefix}3.${Font_color_suffix} ֹͣ BBR
 ${Green_font_prefix}4.${Font_color_suffix} �鿴 BBR ״̬" && echo
echo -e "${Green_font_prefix} [��װǰ ��ע��] ${Font_color_suffix}
1. ��װ����BBR����Ҫ�����ںˣ����ڸ���ʧ�ܵȷ���(�������޷�����)
2. ���ű���֧�� Debian / Ubuntu ϵͳ�����ںˣ�OpenVZ��Docker ��֧�ָ����ں�
3. Debian �����ں˹����л���ʾ [ �Ƿ���ֹж���ں� ] ����ѡ�� ${Green_font_prefix} NO ${Font_color_suffix}" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" bbr_num
	[[ -z "${bbr_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${bbr_num} == "1" ]]; then
		Install_BBR
	elif [[ ${bbr_num} == "2" ]]; then
		Start_BBR
	elif [[ ${bbr_num} == "3" ]]; then
		Stop_BBR
	elif [[ ${bbr_num} == "4" ]]; then
		Status_BBR
	else
		echo -e "${Error} ��������ȷ������(1-4)" && exit 1
	fi
}
Install_BBR(){
	[[ ${release} = "centos" ]] && echo -e "${Error} ���ű���֧�� CentOSϵͳ��װ BBR !" && exit 1
	BBR_installation_status
	bash "${BBR_file}"
}
Start_BBR(){
	BBR_installation_status
	bash "${BBR_file}" start
}
Stop_BBR(){
	BBR_installation_status
	bash "${BBR_file}" stop
}
Status_BBR(){
	BBR_installation_status
	bash "${BBR_file}" status
}
# ��������
Other_functions(){
	echo && echo -e "  ��Ҫ��ʲô��
	
  ${Green_font_prefix}1.${Font_color_suffix} ���� BBR
  ${Green_font_prefix}2.${Font_color_suffix} ���� ����(ServerSpeeder)
  ${Green_font_prefix}3.${Font_color_suffix} ���� LotServer(����ĸ��˾)
  ע�⣺ ����/LotServer/BBR ��֧�� OpenVZ��
  ע�⣺ ����/LotServer/BBR ���ܹ��棡
������������������������
  ${Green_font_prefix}4.${Font_color_suffix} һ����� BT/PT/SPAM (iptables)
  ${Green_font_prefix}5.${Font_color_suffix} һ����� BT/PT/SPAM (iptables)
  ${Green_font_prefix}6.${Font_color_suffix} �л� ShadowsocksR��־���ģʽ
  ����˵����SSRĬ��ֻ���������־��������л�Ϊ�����ϸ�ķ�����־" && echo
	stty erase '^H' && read -p "(Ĭ��: ȡ��):" other_num
	[[ -z "${other_num}" ]] && echo "��ȡ��..." && exit 1
	if [[ ${other_num} == "1" ]]; then
		Configure_BBR
	elif [[ ${other_num} == "2" ]]; then
		Configure_Server_Speeder
	elif [[ ${other_num} == "3" ]]; then
		Configure_LotServer
	elif [[ ${other_num} == "4" ]]; then
		BanBTPTSPAM
	elif [[ ${other_num} == "5" ]]; then
		UnBanBTPTSPAM
	elif [[ ${other_num} == "6" ]]; then
		Set_config_connect_verbose_info
	else
		echo -e "${Error} ��������ȷ������ [1-6]" && exit 1
	fi
}
# ��� BT PT SPAM
BanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh banall
	rm -rf ban_iptables.sh
}
# ��� BT PT SPAM
UnBanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh unbanall
	rm -rf ban_iptables.sh
}
Set_config_connect_verbose_info(){
	SSR_installation_status
	Get_User
	if [[ ${connect_verbose_info} = "0" ]]; then
		echo && echo -e "��ǰ��־ģʽ: ${Green_font_prefix}��ģʽ��ֻ���������־��${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ${Green_font_prefix}��ϸģʽ�������ϸ������־+������־��${Font_color_suffix}��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="1"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo && echo -e "��ǰ��־ģʽ: ${Green_font_prefix}��ϸģʽ�������ϸ������־+������־��${Font_color_suffix}" && echo
		echo -e "ȷ��Ҫ�л�Ϊ ${Green_font_prefix}��ģʽ��ֻ���������־��${Font_color_suffix}��[y/N]"
		stty erase '^H' && read -p "(Ĭ��: n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="0"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	��ȡ��..." && echo
		fi
	fi
}
Update_Shell(){
	echo -e "��ǰ�汾Ϊ [ ${sh_ver} ]����ʼ������°汾..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://softs.loan/Bash/ssr.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="softs"
	[[ -z ${sh_new_ver} ]] && sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssr.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} ������°汾ʧ�� !" && exit 0
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e "�����°汾[ ${sh_new_ver} ]���Ƿ���£�[Y/n]"
		stty erase '^H' && read -p "(Ĭ��: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			if [[ -e "/etc/init.d/ssr" ]]; then
				rm -rf /etc/init.d/ssr
				Service_SSR
			fi
			if [[ $sh_new_type == "softs" ]]; then
				wget -N --no-check-certificate https://softs.loan/Bash/ssr.sh && chmod +x ssr.sh
			else
				wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssr.sh && chmod +x ssr.sh
			fi
			echo -e "�ű��Ѹ���Ϊ���°汾[ ${sh_new_ver} ] !"
		else
			echo && echo "	��ȡ��..." && echo
		fi
	else
		echo -e "��ǰ�������°汾[ ${sh_new_ver} ] !"
	fi
}
# ��ʾ �˵�״̬
menu_status(){
	if [[ -e ${config_user_file} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e " ��ǰ״̬: ${Green_font_prefix}�Ѱ�װ${Font_color_suffix} �� ${Green_font_prefix}������${Font_color_suffix}"
		else
			echo -e " ��ǰ״̬: ${Green_font_prefix}�Ѱ�װ${Font_color_suffix} �� ${Red_font_prefix}δ����${Font_color_suffix}"
		fi
		now_mode=$(cat "${config_user_file}"|grep '"port_password"')
		if [[ -z "${now_mode}" ]]; then
			echo -e " ��ǰģʽ: ${Green_font_prefix}���˿�${Font_color_suffix}"
		else
			echo -e " ��ǰģʽ: ${Green_font_prefix}��˿�${Font_color_suffix}"
		fi
	else
		echo -e " ��ǰ״̬: ${Red_font_prefix}δ��װ${Font_color_suffix}"
	fi
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} ���ű���֧�ֵ�ǰϵͳ ${release} !" && exit 1
echo -e "  ShadowsocksR һ������ű� ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- Toyo | doub.io/ss-jc42 ----

  ${Green_font_prefix}1.${Font_color_suffix} ��װ ShadowsocksR
  ${Green_font_prefix}2.${Font_color_suffix} ���� ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix} ж�� ShadowsocksR
  ${Green_font_prefix}4.${Font_color_suffix} ��װ libsodium(chacha20)
������������������������
  ${Green_font_prefix}5.${Font_color_suffix} �鿴 �˺���Ϣ
  ${Green_font_prefix}6.${Font_color_suffix} ��ʾ ������Ϣ
  ${Green_font_prefix}7.${Font_color_suffix} ���� �û�����
  ${Green_font_prefix}8.${Font_color_suffix} �ֶ� �޸�����
  ${Green_font_prefix}9.${Font_color_suffix} �л� �˿�ģʽ
������������������������
 ${Green_font_prefix}10.${Font_color_suffix} ���� ShadowsocksR
 ${Green_font_prefix}11.${Font_color_suffix} ֹͣ ShadowsocksR
 ${Green_font_prefix}12.${Font_color_suffix} ���� ShadowsocksR
 ${Green_font_prefix}13.${Font_color_suffix} �鿴 ShadowsocksR ��־
������������������������
 ${Green_font_prefix}14.${Font_color_suffix} ��������
 ${Green_font_prefix}15.${Font_color_suffix} �����ű�
 "
menu_status
echo && stty erase '^H' && read -p "���������� [1-15]��" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Update_SSR
	;;
	3)
	Uninstall_SSR
	;;
	4)
	Install_Libsodium
	;;
	5)
	View_User
	;;
	6)
	View_user_connection_info
	;;
	7)
	Modify_Config
	;;
	8)
	Manually_Modify_Config
	;;
	9)
	Port_mode_switching
	;;
	10)
	Start_SSR
	;;
	11)
	Stop_SSR
	;;
	12)
	Restart_SSR
	;;
	13)
	View_Log
	;;
	14)
	Other_functions
	;;
	15)
	Update_Shell
	;;
	*)
	echo -e "${Error} ��������ȷ������ [1-15]"
	;;
esac