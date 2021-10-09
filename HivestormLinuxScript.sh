#!/bin/bash
# Discription: Linux lockdown script
# Author: TNAR5
# Version: 1

CURRENT_USER=$(logname)
HEADER='\e[1m'
RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function notify()
{
	echo -e "$YELLOW[!]$NC $1"
}

function error()
{
	echo -e "$RED[-]$NC $1"
}

function success()
{
	echo -e "$GREEN[+]$NC $1"
}

function header()
{
	echo -e "$HEADER$1$NC"
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

header "Linux Lockdown Script"
echo "Author........: TNAR5"
echo "Version.......: 1.0"
echo "OS............: $(uname -o)"
echo "Executing User: $(logname)"

printf "\n\n"

read -p "[?] Have you read the README and the Forensics Questions? [y/n]" -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]
then
	error "Please read the files on the desktop to make sure that the script is not messing with anything essential."
	exit 1
fi


function ssh_lockdown()
{	
	header "\nSSH Lockdown"
	if dpkg --get-selections | grep -q "^openssh-server[[:space:]]*install$" >/dev/null;then
		success "SSH is installed switching to secure config."
		cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
		printf "Port 22\nPermitRootLogin no\nListenAddress 0.0.0.0\nMaxAuthTries 3\nMaxSessions 1\nPubkeyAuthentication yes\nPermitEmptyPasswords no\nUsePAM yes\nPrintMotd yes\nAcceptEnv LANG LC_*\nSubsystem\tsftp\t/usr/lib/openssh/sftp-server" > /etc/ssh/sshd_config
	else
		error "SSH is not installed."
	fi
}

function kernel_lockdown()
{
	header "\nKernel Lockdown"
	success "Enabling secure Kernel options."
	cp /etc/sysctl.conf /etc/sysctl.conf.bak
	printf "net.ipv4.conf.default.rp_filter=1\nnet.ipv4.conf.all.rp_filter=1\nnet.ipv4.tcp_syncookies=1\nnet.ipv4.ip_forward=0\nnet.ipv4.conf.all.accept_redirects=0\nnet.ipv6.conf.all.accept_redirects=0\nnet.ipv4.conf.all.send_redirects=0\nnet.ipv4.conf.all.accept_source_route=0\nnet.ipv6.conf.all.accept_source_route=0\nnet.ipv4.conf.all.log_martians=1\nnet.ipv4.icmp_echo_ignore_broadcasts=1\nnet.ipv6.conf.all.disable_ipv6=0\nnet.ipv6.conf.default.disable_ipv6=0\nnet.ipv6.conf.lo.disable_ipv6=1\nkernel.core_uses_pid=1\nkernel.sysrq=0" > /etc/sysctl.conf
	sysctl -w kernel.randomize_va_space=2 >/dev/null;sysctl -w net.ipv4.conf.default.rp_filter=1>/dev/null;sysctl -w net.ipv4.conf.all.rp_filter=1>/dev/null;sysctl -w net.ipv4.tcp_syncookies=1>/dev/null;sysctl -w net.ipv4.ip_forward=0>/dev/null;sysctl -w net.ipv4.conf.all.accept_redirects=0>/dev/null;sysctl -w net.ipv6.conf.all.accept_redirects=0>/dev/null;sysctl -w net.ipv4.conf.all.send_redirects=0>/dev/null;sysctl -w net.ipv4.conf.all.accept_source_route=0>/dev/null;sysctl -w net.ipv6.conf.all.accept_source_route=0>/dev/null;sysctl -w net.ipv4.conf.all.log_martians=1>/dev/null;
}

function lockout_policy()
{
echo "c"
} 

function user_lockdown()
{
	header "\nUser Lockdown"
	notify "Starting interactive user lockdown."
	success "Backup user list /home/$CURRENT_USER/users.txt"
	getent passwd | grep "home" | cut -d ':' -f 1 > /home/$CURRENT_USER/users.txt
	users=($(getent passwd | grep "home" | cut -d ':' -f 1))
	success "Found "${#users[@]}" users."
	for u in "${users[@]}"
	do
		read -p "[?] Is user ${u} authorized to be on the system? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Nn]$ ]]
		then
			userdel $u
			groupdel $u
			success "${u} has been removed."
		else
			read -p "[?] Would you like to change their password? [y/n]" -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]
			then
				passwd $u
			fi
			read -p "[?] Is this user an administrator? [y/n]" -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]
			then
				groups $u | grep "sudo" > /dev/null
				if [ $? -eq 0 ];
				then 
					success "User is an Administrator - no change."
				else
					usermod -aG sudo $u
					success "User was added to the sudo group."
				fi
			else
				groups $u | grep "sudo" > /dev/null
				if [ $? -eq 0 ];
				then 
					notify "User was an Administrator."
					deluser $u sudo
					success "Removed ${u} from sudo group."
				else
					success "User is not an Administrator - no change."
				fi			
			fi
			

		fi
	done
	read -p "[?] Press any key to check sudoers." -n 1 -r
	echo ""
	success "Launching visudo."
	visudo
	printf "\n"
	

}

function enable_ufw()
{
	header "\nFirewall Lockdown"
	command -v ufw >/dev/null
	if [ $? -eq 0 ];then
		success "UFW found enableing firewall."
		ufw enable > /dev/null
	else
		error "UFW not installed."
		read -p "[?] Would you like to install ufw? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			apt-get install -y ufw
			ufw enable > /dev/null
			success "UFW is now enabled."
		fi
	fi
}

function enable_av()
{
	header "\nAnti-Virus lockdown"
	command -v clamscan >/dev/null
	if [ $? -eq 0 ];then
		success "ClamAV found."
		freshclam
		success "Updated definitions."
	else
		error "ClamAV not installed."
		read -p "[?] Would you like to install ClamAV and chkrootkit? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			apt-get install -y clamav chkrootkit
			ufw enable > /dev/null
			freshclam
			success "ClamAV is now enabled and updated."
		fi
	fi
}

function ask_to_install_updates()
{
	header "\nInstalling Updates"
	read -p "[?] Would you like to install updates? [y/n] " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		apt-get update
		apt-get upgrade -y
		apt-get dist-upgrade -y
	fi
}

function check_configs()
{
	read -p "[?] Would you like to check random system config files? [y/n] " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			echo "nospoof on" >> /etc/hosts
			vim /etc/hosts
			vim /etc/crontab
			echo "The following users have active crontabs:"
			ls /var/spool/cron/crontabs
			read -p "[!] Make sure to set lightdm guest to false and auto login is disabled. (allow-guest=False)" -n 1 -r
			vim /etc/lightdm/lightdm.conf
			printf "\n"
			success "Finish config editing."
		fi

}

function check_bad_programs()
{
	header 	"\nChecking for 'bad' programs."
	if dpkg --get-selections | grep -q "^nmap[[:space:]]*install$" >/dev/null;then
		notify "Nmap is installed, removing."
		apt-get purge nmap
	fi
	if dpkg --get-selections | grep -q "^john[[:space:]]*install$" >/dev/null;then
		notify "John is installed, removing."
		apt-get purge john
	fi
	if dpkg --get-selections | grep -q "^rainbowcrack[[:space:]]*install$" >/dev/null;then
		notify "rainbowcrack is installed, removing."
		apt-get purge rainbowcrack
	fi
	if dpkg --get-selections | grep -q "^ophcrack[[:space:]]*install$" >/dev/null;then
		notify "Ophcrack is installed, removing."
		apt-get purge ophcrack
	fi
	if dpkg --get-selections | grep -q "^nc[[:space:]]*install$" >/dev/null;then
		notify "Nc is installed, removing."
		apt-get purge nc
	fi
	if dpkg --get-selections | grep -q "^netcat[[:space:]]*install$" >/dev/null;then
		notify "Netcat is installed, removing."
		apt-get purge netcat
	fi
	if dpkg --get-selections | grep -q "^hashcat[[:space:]]*install$" >/dev/null;then
		notify "Hashcat is installed, removing."
		apt-get purge hashcat
	fi
	if dpkg --get-selections | grep -q "^telnet[[:space:]]*install$" >/dev/null;then
		warn "Telnet is installed, removing."
		apt-get purge telnet
	fi
	apt-get purge netcat*

	if dpkg --get-selections | grep -q "^samba[[:space:]]*install$" >/dev/null;then
		notify "Samba is installed, make sure this is a required service."
	fi
	if dpkg --get-selections | grep -q "^bind9[[:space:]]*install$" >/dev/null;then
		notify "Bind9 is installed, make sure this is a required service."
	fi
	if dpkg --get-selections | grep -q "^vsftpd[[:space:]]*install$" >/dev/null;then
		notify "Vsftpd is installed, make sure this is a required service."
	fi
	if dpkg --get-selections | grep -q "^apache2[[:space:]]*install$" >/dev/null;then
		notify "Apache2 is installed, make sure this is a required service."
	fi
	if dpkg --get-selections | grep -q "^nginx[[:space:]]*install$" >/dev/null;then
		notify "Nginx is installed, make sure this is a required service."
	fi
	if dpkg --get-selections | grep -q "^telnet[[:space:]]*install$" >/dev/null;then
		notify "Telnet is installed, make sure this is a required service."
	fi
	success "Displaying other active services:"
	service --status-all | grep '+'
	echo ""
}

function find_media()
{
	chkdir="/home/"
	dmpfile="/home/${CURRENT_USER}/media_files.txt"
	sarray=()	
	header "Checking for media files in ${chkdir}"
	success "Checking txt files."
	echo "">$dmpfile
	sarray=($(find $chkdir -type f -name "*.txt" | tee -a $dmpfile))
	echo "Found ${#sarray[@]}"
	success "Checking mp4 files."
	sarray=($(find $chkdir -type f -name "*.mp4" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]}"
	success "Checking mp3 files."
	sarray=($(find $chkdir -type f -name "*.mp3" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]}"	
	success "Checking ogg files."
	sarray=($(find $chkdir -type f -name "*.ogg" | tee -a $dmpfile))
	echo "Found ${#sarray[@]}"
	success "Checking wav files."
	sarray=($(find $chkdir -type f -name "*.wav" | tee -a $dmpfile))
	echo "Found ${#sarray[@]}"
	success "Checking png files."
	sarray=($(find $chkdir -type f -name "*.png" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]}"
	success "Checking jpg files."
	sarray=($(find $chkdir -type f -name "*.jpg" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]} jpg"	
	sarray=($(find $chkdir -type f -name "*.jpeg" | tee -a  $dmpfile)) 
	echo "Found ${#sarray[@]} jpeg"
	success "Checking gif files."
	sarray=($(find $chkdir -type f -name "*.gif" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]}"	
	success "Checking mov files."
	sarray=($(find $chkdir -type f -name "*.mov" | tee -a  $dmpfile))
	echo "Found ${#sarray[@]}"
	printf "\n"
	notify "Saving file paths to ${dmpfile}"	
	
}


if [ "$1" == "-a" ];then
success "Running in auto script mode."
ssh_lockdown
enable_ufw
enable_av
kernel_lockdown
check_bad_programs
ask_to_install_updates
find_media
else
ssh_lockdown
enable_ufw
enable_av
kernel_lockdown
user_lockdown
check_configs
check_bad_programs
ask_to_install_updates
find_media
fi

header "\nThings left to do:"
notify "~Update kernel"
notify "Pam cracklib password requirements/logging"
notify "Discover rootkits/backdoors"
notify "Check file permissions"
notify "Check init scripts"
notify "Set GUI update options for package manager bc idk"
notify "Web browser updates and security"
notify "ADD USERS NOT IN THE LIST"
notify "Win"

success "Script finished exiting."
exit 0
