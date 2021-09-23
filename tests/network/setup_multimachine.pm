# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test preparing the static IP and hostname for simple multimachine tests
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(permit_root_ssh);
use zypper;
use Utils::Systemd qw(disable_and_stop_service systemctl);
use version_utils qw(is_sle is_opensuse);

sub is_networkmanager {
    return (script_run('readlink /etc/systemd/system/network.service | grep NetworkManager') == 0);
}

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    select_console 'root-console';
    my $nm_id = is_sle('15-sp3+') ? 'eth0' : 'Wired connection 1';

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);

    # Configure the internal network an  try it
    if ($hostname =~ /server|master/) {
        setup_static_mm_network('10.0.2.101/24');

        if (is_networkmanager) {
            assert_script_run "nmcli connection modify '$nm_id' ifname 'eth0' ip4 '10.0.2.101/24' gw4 10.0.2.2 ipv4.method manual ";
            assert_script_run "nmcli connection down '$nm_id'";
            assert_script_run "nmcli connection up '$nm_id'";
        }
        else {
            assert_script_run 'systemctl restart  wicked';
        }
    }
    else {
        setup_static_mm_network('10.0.2.102/24');

        if (is_networkmanager) {
            assert_script_run "nmcli connection modify '$nm_id' ifname 'eth0' ip4 '10.0.2.102/24' gw4 10.0.2.2 ipv4.method manual ";
            assert_script_run "nmcli connection down '$nm_id'";
            assert_script_run "nmcli connection up '$nm_id'";
        }
        else {
            systemctl("restart wicked");
        }
    }

    # Set the hostname to identify both minions
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname|grep $hostname";

    # Make sure that PermitRootLogin is set to yes
    # This is needed only when the new SSH config directory exists
    # See: poo#93850
    permit_root_ssh();
}

1;

