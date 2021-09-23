# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: gcc
# Summary: additional gcc tests
# - gcc-jit test according to https://gcc.gnu.org/onlinedocs/jit/intro/tutorial02.html
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use zypper;
use testapi;
use utils;
use version_utils qw(is_tumbleweed);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    ## Note: Because this test currently only includes the gcc-jit test, the module is scheduled on Tumbleweed only
    ## When extending the test, consider scheduling it on SLES/Leap as well.

    # Test gccjit (tumbleweed only, because it's a very new feature)
    # See https://bugzilla.opensuse.org/show_bug.cgi?id=1185529 for the reason behind this test
    # and https://gcc.gnu.org/onlinedocs/jit/intro/tutorial02.html for the test template.
    if (is_tumbleweed) {
        zypper_call 'in gcc libgccjit0 libgccjit0-devel-gcc11';
        assert_script_run 'curl -v -o gcc-jit.c ' . data_url('gcc/gcc-jit.c');
        assert_script_run 'gcc gcc-jit.c -o gcc-jit -lgccjit';
        validate_script_output './gcc-jit', sub { m/result: 25/ };
    }
}

sub post_run_hook {
    my $self = shift;
    script_run("rm -f gcc-jit.c gcc-jit");
    $self->SUPER::post_run_hook;
}

1;
