#!/usr/bin/perl


#    Anonymiser 0.9 - Quick and convenient system-wide anonymiser using Tor transparently
#    Copyright (C) 2011 Andy Dixon
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# the config file /etc/anonymiser.conf needs to have any internal (LAN) network
# subnet masks and also the user in which Tor runs as. 
# An example of the config file is as follows:

# @mynets = ("192.168.0.0/24","192.168.1.0/24","10.0.0.0/8");
# $TOR_UID = `id -u debian-tor`;
# 1;
#
# The 1 at the end is required. Without it the anonymiser will fail.
#

print "anonymiser Copyright (C) 2011 Andy Dixon
    This program comes with ABSOLUTELY NO WARRANTY; for details view the GPL license at http://www.gnu.org/licenses/gpl.html.
    This is free software, and you are welcome to redistribute it
    under certain conditions; for details, refer to the GPL license above.\n";

require "/etc/anonymiser.conf" or die "Error: Missing configuration file.\n";

$TRANS_PORT="9040";
$UBUNTU_VERSION=`lsb_release -c -s`;
chomp $TOR_UID;
chomp $UBUNTU_VERSION;

# Check user is root or sudo user
if ( $< == 0 ) {

	#Backup any existing configuration
	print "Backing up existing IPTables...";
	system("iptables-save -c > /etc/iptables-torbackup");
	print "Saved as /etc/iptables-backup\n";	
	system("cp /etc/resolv.conf /etc/resolv.conf.torbackup");

	#Check if Ubuntu is being run, if so, check for Tor
	if ($UBUNUTU_VERSION == "maverick" || $UBUNTU_VERSION == "natty") { 

		system("which tor >/dev/null");
		#If Tor is not installed, install it
		if ($? == 256 ) {
			print "Prerequisites not met. Installing....\n";
			open IN, '<', "/etc/apt/sources.list" or die;
			my @contents = <IN>;
			close IN;
	
			@contents = grep !/^$deb\ http\:\/\/deb.torproject.org\/torproject.org\ maverick\ main/, @contents;

			open OUT, '>', "/etc/apt/sources.list" or die;
			print OUT @contents;
			close OUT;
			tryexec("echo \"deb http://deb.torproject.org/torproject.org maverick main\" >> /etc/apt/sources.list","true");
			tryexec("gpg --keyserver keys.gnupg.net --recv 886DDD89","true");
			tryexec("gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -","true");
			tryexec("apt-get update >/dev/null 2>&1","true");
			tryexec("apt-get -y install tor >/dev/null 2>&1","true");
		}
	}

	system("iptables -F");
	system("iptables -t nat -F");
	system("iptables -t nat -A OUTPUT -m owner --uid-owner $TOR_UID -j RETURN");
	system("iptables -t nat -A OUTPUT -d 127.0.0.0/9 -j RETURN");
	system("iptables -t nat -A OUTPUT -d 127.128.0.0/10 -j RETURN");
	foreach (@mynets) {
	 	system("iptables -t nat -A OUTPUT -d $_	-j RETURN");
		system("iptables -A OUTPUT -d $_ -j ACCEPT");
	} 
	system("iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53");
	system("iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT");
	system("iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT");
	system("iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT");
	system("iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT");
	system("iptables -A OUTPUT -j REJECT");

	open IN, '<', "/etc/tor/torrc" or revertChanges("Cant open transport config for reading.\n");
	my @contents = <IN>;
	close IN;

	@contents = grep !/^$AutomapHostsOnResolve\ 1/, @contents;
	@contents = grep !/^$TransPort\ 9040/, @contents;
	@contents = grep !/^$DNSPort\ 53/, @contents;

	open OUT, '>', "/etc/tor/torrc" or revertChanges("Cant open transport config for writing.\n");
	print OUT @contents;
	close OUT;

	system("echo \"AutomapHostsOnResolve 1\" >>/etc/tor/torrc");
	system("echo \"TransPort 9040\" >>/etc/tor/torrc");
	system("echo \"DNSPort 53\" >>/etc/tor/torrc");
	system("/etc/init.d/tor restart");
	system("echo \"nameserver 127.0.0.1\" > /etc/resolv.conf");
} else {
	print "You must be running as root or with sudo privileges.\n";
}


sub tryexec {

	my($cmd,$hardFail) = @_;
	system($cmd);
	if ($? == 0 ) {
		return true;
	}
	if ($hardFail) {
		revertChanges("Something failed.\n");
	}
	return false;
}

sub revertChanges {
		print $_;
		print "Error Ocurred. Reverting Changes...\n";
		system("mv /etc/resolv.conf.torbackup /etc/resolv.conf");
		system("iptables -F");
		system("iptables -t nat -F");
		system("iptables-restore -c < /etc/iptables-torbackup");
		die("\nSystem Restored. Aborting.\n");
}
