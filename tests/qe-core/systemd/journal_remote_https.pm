# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-journal-remote
# Summary: - Send logs via systemd-journal-upload
#          - Collect them back via systemd-journal-remote
#          - Done on single machine and using https
# Maintainer: qe-core@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    zypper_call("in systemd-journal-remote");

    ### Setup receiver service
    assert_script_run("mkdir -p /var/log/journal/remote");

    systemctl('enable systemd-journal-remote.socket');
    assert_script_run("sed -i --follow-symlinks \'s/^ListenStream=.*\$/ListenStream=9090/\' /etc/systemd/system/sockets.target.wants/systemd-journal-remote.socket");

    assert_script_run("cp /usr/lib/systemd/system/systemd-journal-remote.service /etc/systemd/system/systemd-journal-remote.service");

    assert_script_run("chown systemd-journal-remote /var/log/journal/remote");

    my $journal_remote_conf = "/etc/systemd/journal-remote.conf";
    assert_script_run("echo '[Remote]' > $journal_remote_conf");
    assert_script_run("echo 'ServerKeyFile=/etc/ssl/private/journal-remote-key.pem' >> $journal_remote_conf");
    assert_script_run("echo 'ServerCertificateFile=/etc/ssl/certs/journal-remote-cert.pem' >> $journal_remote_conf");
    assert_script_run("echo 'TrustedCertificateFile=/etc/ssl/ca/journal-remote-ca-cert.pem' >> $journal_remote_conf");

    ## Create server keys
    assert_script_run("mkdir -p /etc/ssl/ca");
    # CA and CA Cert
    assert_script_run("openssl genrsa 2048 > /etc/ssl/ca/journal-remote-ca-key.pem");
    assert_script_run("openssl req -new -x509 -nodes -days 365000 -key /etc/ssl/ca/journal-remote-ca-key.pem -out /etc/ssl/ca/journal-remote-ca-cert.pem -subj '/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acmeCA.com'");
    # Server Key and Cert Req
    assert_script_run("openssl req -newkey rsa:2048 -nodes -days 365000 -keyout /etc/ssl/private/journal-remote-key.pem -out /etc/ssl/private/journal-remote-req.pem -subj '/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acme.com'");
    # Server Cert signed by CA
    assert_script_run("openssl x509 -req -days 365000 -set_serial 01 -in /etc/ssl/private/journal-remote-req.pem -out /etc/ssl/certs/journal-remote-cert.pem -CA /etc/ssl/ca/journal-remote-ca-cert.pem -CAkey /etc/ssl/ca/journal-remote-ca-key.pem");
    # Give ownership
    assert_script_run("chown systemd-journal-remote /etc/ssl/private/journal-remote-key.pem");
    assert_script_run("chown systemd-journal-remote /etc/ssl/certs/journal-remote-cert.pem");
    assert_script_run("chown systemd-journal-remote /etc/ssl/ca/journal-remote-ca-cert.pem");


    ### Setup uploader service

    my $journal_upload_conf = "/etc/systemd/journal-upload.conf";
    assert_script_run("echo '[Upload]' > $journal_upload_conf");
    assert_script_run("echo 'URL=https://127.0.0.1:9090' > $journal_upload_conf");
    assert_script_run("echo 'ServerKeyFile=/etc/ssl/private/journal-upload-key.pem' >> $journal_upload_conf");
    assert_script_run("echo 'ServerCertificateFile=/etc/ssl/certs/journal-upload-cert.pem' >> $journal_upload_conf");
    assert_script_run("echo 'TrustedCertificateFile=/etc/ssl/ca/journal-upload-ca-cert.pem' >> $journal_upload_conf");


    ## Create client keys
    # The default configuration for systemd-journal-upload is that it uses a temporary user that only exists while the process is running. This makes allowing systemd-journal-upload to read the TLS certificates and keys more complicated. To resolve this you will create a new system user with the same name as the temporary user that will get used in its place.
    assert_script_run("useradd --system --home-dir /run/systemd --no-create-home --groups systemd-journal-upload");
    # CA and CA Cert
    assert_script_run("openssl genrsa 2048 > /etc/ssl/ca/journal-upload-ca-key.pem");
    assert_script_run("openssl req -new -x509 -nodes -days 365000 -key /etc/ssl/ca/journal-upload-ca-key.pem -out /etc/ssl/ca/journal-upload-ca-cert.pem -subj '/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acmeCA.com'");
    # Server Key and Cert Req
    assert_script_run("openssl req -newkey rsa:2048 -nodes -days 365000 -keyout /etc/ssl/private/journal-upload-key.pem -out /etc/ssl/private/journal-upload-req.pem -subj '/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acme.com'");
    # Server Cert signed by CA
    assert_script_run("openssl x509 -req -days 365000 -set_serial 01 -in /etc/ssl/private/journal-upload-req.pem -out /etc/ssl/certs/journal-upload-cert.pem -CA /etc/ssl/ca/journal-upload-ca-cert.pem -CAkey /etc/ssl/ca/journal-upload-ca-key.pem");
    # Give ownership
    assert_script_run("chown systemd-journal-upload /etc/ssl/private/journal-upload-key.pem");
    assert_script_run("chown systemd-journal-upload /etc/ssl/certs/journal-upload-cert.pem");
    assert_script_run("chown systemd-journal-upload /etc/ssl/ca/journal-upload-ca-cert.pem");

    systemctl('enable systemd-journal-upload.service');
    

#https://mariadb.com/docs/server/security/data-in-transit-encryption/create-self-signed-certificates-keys-openssl/
# uploader needs cert in /etc/pki/systemd/certs/journal-upload.pem ?
# needs certs /etc/systemd/journal-upload.conf  https://www.digitalocean.com/community/tutorials/how-to-centralize-logs-with-journald-on-debian-10

    # Start them both
    assert_script_run("systemctl daemon-reload");
    systemctl('restart systemd-journal-remote.socket');
    script_run("sleep 3");
    systemctl('restart systemd-journal-upload.service');
    script_run("sleep 3");

    # Send a log message and look for it on both local and remote journalctl
    assert_script_run("echo 'TEST_MESSAGE_FOR_JOURNAL_UPLOADER' | systemd-cat");
    script_run("sleep 3");
    assert_script_run('journalctl --since "10 min ago" -g TEST_MESSAGE_FOR_JOURNAL_UPLOADER');
    assert_script_run('journalctl  --file /var/log/journal/remote/remote-127.0.0.1.journal --since "10 min ago" -g TEST_MESSAGE_FOR_JOURNAL_UPLOADER');


}

1;

