# SUSE's openQA tests
#
# Copyright © 2020 SUSE
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Full patch system using zypper
# - Calls zypper dup
# Maintainer:

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Mitigation;

sub run {
    my $self = shift;
    select_console 'root-console';
    zypper_call("dup --replacefiles", timeout => 1800);

    Mitigation::reboot_and_wait($self, 300);
}


1;
