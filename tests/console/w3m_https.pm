# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1525204 - FIPS: w3m_https

# Package: w3m
# Summary: Add w3m_https test case and fips test entry
#    Add w3m_https.pm test case was located in console/w3m_https.pm
#    Add w3m_https.pm test entry in load_fips_tests_web() in sle/main.pm
# Maintainer: Ben Chou <bchou@suse.com>

use base "consoletest";
use strict;
use warnings;
use zypper;
use testapi;

use web_browser qw(setup_web_browser_env run_web_browser_text_based);

sub run {
    select_console("root-console");
    zypper_call("--no-refresh --no-gpg-checks search -it pattern fips") if get_var('FIPS_ENABLED');
    zypper_call("--no-refresh --no-gpg-checks in w3m");
    run_web_browser_text_based("w3m", undef);
}

1;
