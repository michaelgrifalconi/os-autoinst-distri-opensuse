# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HotFix for UEFI SecureBoot issue for sle12sp5
# Maintainer: QA-c <qa-c@suse.com>

use Mojo::Base qw(opensusebasetest);
use testapi qw(select_console assert_script_run get_var);

use zypper;
use power_action_utils qw(power_action);

sub run {
    select_console 'root-console';
    return unless get_var('UEFI');
    # pbl should be aware of SecureBoot
    assert_script_run('echo SECURE_BOOT=yes >> /etc/sysconfig/bootloader');
    # install kernel with builtin efivars (/sys/firmware/efi/efivars/)
    zypper_call('update kernel-default-base');
    # boot the new kernel
    power_action('reboot', textmode => 1);
    shift->wait_boot(bootloader_time => get_var('BOOTLOADER_TIMEOUT', 150));
}

1;
