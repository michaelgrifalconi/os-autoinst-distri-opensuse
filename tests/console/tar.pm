# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: tar
# Summary: -  Verify the correct version of tar is in 15-SP4
#          -  Create tar + zstd functionality automatic test 
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle);

sub run {

my $self = shift;
$self->select_serial_terminal;

## all cases:
# - generate test data to be compressed
### To decide what to do (/data/console or generated)

assert_script_run "wget --quiet " . data_url('console/tar_test.tar');
assert_script_run("tar -xvf tar_test.tar tar_test");

# - compress -j and extract
assert_script_run("tar -cjvf myfile.tar.bz2 tar_test");
assert_script_run("tar -xjvf myfile.tar.bz2 -C extracted_dir");
assert_script_run("rm -rf extracted_dir");

# - compress -J and extract
assert_script_run("tar -cJvf myfile.tar.xz tar_test");
assert_script_run("tar -xJvf myfile.tar.xz -C extracted_dir");
assert_script_run("rm -rf extracted_dir");

# - compress -z and extract
assert_script_run("tar -czvf myfile.tar.gz tar_test");
assert_script_run("tar -xzvf myfile.tar.gz -C extracted_dir");
assert_script_run("rm -rf extracted_dir");

# - compress -a file.tar.gzip and extract
assert_script_run("tar -azvf myfile.tar.gz tar_test");
assert_script_run("tar -xavf myfile.tar.gz -C extracted_dir");
assert_script_run("rm -rf extracted_dir");

## if > than 15-SP1
if (is_sle('>=15-sp1')) {
    # - compress -I zstd and extract
    assert_script_run("tar -I zstd -cvf myfile.tar.zst tar_test");
    assert_script_run("tar -I zstd -xvf myfile.tar.zst -C extracted_dir");
    assert_script_run("rm -rf extracted_dir");
}



## if > than 15-SP4
if (is_sle('>=15-sp4')) {
    # - compress --zstd and extract
    assert_script_run("tar --zstd -cvf myfile.tar.zst tar_test");
    assert_script_run("tar --zstd -xvf myfile.tar.zst -C extracted_dir");
    assert_script_run("rm -rf extracted_dir");

    # - compress -acvf myfile.tar.zstd and extract tar xvf package.tar.zst
    assert_script_run("tar -azvf myfile.tar.zst tar_test");
    assert_script_run("tar -xavf myfile.tar.zst -C extracted_dir");
    assert_script_run("rm -rf extracted_dir");

    # test tar version >= 1.34
    ## TODO
}



}

1;