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

    assert_script_run($_, 600) foreach (split /\n/, <<~'EOF');


    TEST_MESSAGE="-= This is a test message $RANDOM =-"
    TEST_TAG="$(systemd-id128 new)"

    echo "$TEST_MESSAGE" | systemd-cat -t "$TEST_TAG"
    journalctl --sync

    /usr/lib/systemd/systemd-journal-remote --version
    /usr/lib/systemd/systemd-journal-remote --help
    /usr/lib/systemd/systemd-journal-upload --version
    /usr/lib/systemd/systemd-journal-upload --help

    # Generate a self-signed certificate for systemd-journal-remote
    #
    # Note: older OpenSSL requires a config file with some extra options, unfortunately
    # Note2: /run here is used on purpose, since the systemd-journal-remote service uses PrivateTmp=yes
    mkdir -p /run/systemd/journal-remote-tls
    cat >/tmp/openssl.conf <<EOB
    [ req ]
    prompt = no
    distinguished_name = req_distinguished_name

    [ req_distinguished_name ]
    C = CZ
    L = Brno
    O = Foo
    OU = Bar
    CN = localhost
    EOB
    openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 7 \
                -config /tmp/openssl.conf \
                -keyout /run/systemd/journal-remote-tls/key.pem \
                -out /run/systemd/journal-remote-tls/cert.pem
    chown -R systemd-journal-remote /run/systemd/journal-remote-tls

    # Configure journal-upload to upload journals to journal-remote without client certificates
    mkdir -p /run/systemd/journal-{remote,upload}.conf.d
    cat >/run/systemd/journal-remote.conf.d/99-test.conf <<EOB
    [Remote]
    SplitMode=host
    ServerKeyFile=/run/systemd/journal-remote-tls/key.pem
    ServerCertificateFile=/run/systemd/journal-remote-tls/cert.pem
    TrustedCertificateFile=-
    EOB
    cat >/run/systemd/journal-upload.conf.d/99-test.conf <<EOB
    [Upload]
    URL=https://localhost:19532
    ServerKeyFile=-
    ServerCertificateFile=-
    TrustedCertificateFile=-
    EOB
    systemd-analyze cat-config systemd/journal-remote.conf
    systemd-analyze cat-config systemd/journal-upload.conf

    systemctl restart systemd-journal-remote.socket
    systemctl restart systemd-journal-upload
    timeout 15 bash -xec 'until systemctl -q is-active systemd-journal-remote.service; do sleep 1; done'
    systemctl status systemd-journal-{remote,upload}

    # It may take a bit until the whole journal is transferred
    timeout 30 bash -xec "until journalctl --directory=/var/log/journal/remote --identifier='$TEST_TAG' --grep='$TEST_MESSAGE'; do sleep 1; done"

    systemctl stop systemd-journal-upload
    systemctl stop systemd-journal-remote.{socket,service}
    rm -rf /var/log/journal/remote/*

    # Now let's do the same, but with a full PKI setup
    #
    # journal-upload keeps the cursor of the last uploaded message, so let's send a fresh one
    echo "$TEST_MESSAGE" | systemd-cat -t "$TEST_TAG"
    journalctl --sync

    mkdir /run/systemd/remote-pki
    cat >/run/systemd/remote-pki/ca.conf <<EOB
    [ req ]
    prompt = no
    distinguished_name = req_distinguished_name

    [ req_distinguished_name ]
    C = CZ
    L = Brno
    O = Foo
    OU = Bar
    CN = Test CA

    [ v3_ca ]
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer:always
    basicConstraints = CA:true
    EOB
    cat >/run/systemd/remote-pki/client.conf <<EOB
    [ req ]
    prompt = no
    distinguished_name = req_distinguished_name

    [ req_distinguished_name ]
    C = CZ
    L = Brno
    O = Foo
    OU = Bar
    CN = Test Client
    EOB
    cat >/run/systemd/remote-pki/server.conf <<EOB
    [ req ]
    prompt = no
    distinguished_name = req_distinguished_name

    [ req_distinguished_name ]
    C = CZ
    L = Brno
    O = Foo
    OU = Bar
    CN = localhost
    EOB
    # Generate a dummy CA
    openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 7 \
                -extensions v3_ca \
                -config /run/systemd/remote-pki/ca.conf \
                -keyout /run/systemd/remote-pki/ca.key \
                -out /run/systemd/remote-pki/ca.crt
    openssl x509 -in /run/systemd/remote-pki/ca.crt -noout -text
    echo 01 >/run/systemd/remote-pki/ca.srl
    # Generate a client key and signing request
    openssl req -nodes -newkey rsa:2048 -sha256 \
                -config /run/systemd/remote-pki/client.conf \
                -keyout /run/systemd/remote-pki/client.key \
                -out /run/systemd/remote-pki/client.csr
    # Sign the request with the CA key
    openssl x509 -req -days 7 \
                -in /run/systemd/remote-pki/client.csr \
                -CA /run/systemd/remote-pki/ca.crt \
                -CAkey /run/systemd/remote-pki/ca.key \
                -out /run/systemd/remote-pki/client.crt
    # And do the same for the server
    openssl req -nodes -newkey rsa:2048 -sha256 \
                -config /run/systemd/remote-pki/server.conf \
                -keyout /run/systemd/remote-pki/server.key \
                -out /run/systemd/remote-pki/server.csr
    openssl x509 -req -days 7 \
                -in /run/systemd/remote-pki/server.csr \
                -CA /run/systemd/remote-pki/ca.crt \
                -CAkey /run/systemd/remote-pki/ca.key \
                -out /run/systemd/remote-pki/server.crt
    chown -R systemd-journal-remote:systemd-journal /run/systemd/remote-pki
    chmod -R g+rwX /run/systemd/remote-pki

    # Reconfigure journal-upload/journal remote with the new keys
    cat >/run/systemd/journal-remote.conf.d/99-test.conf <<EOB
    [Remote]
    SplitMode=host
    ServerKeyFile=/run/systemd/remote-pki/server.key
    ServerCertificateFile=/run/systemd/remote-pki/server.crt
    TrustedCertificateFile=/run/systemd/remote-pki/ca.crt
    EOB
    cat >/run/systemd/journal-upload.conf.d/99-test.conf <<EOB
    [Upload]
    URL=https://localhost:19532
    ServerKeyFile=/run/systemd/remote-pki/client.key
    ServerCertificateFile=/run/systemd/remote-pki/client.crt
    TrustedCertificateFile=/run/systemd/remote-pki/ca.crt
    EOB
    systemd-analyze cat-config systemd/journal-remote.conf
    systemd-analyze cat-config systemd/journal-upload.conf

    systemctl restart systemd-journal-remote.socket
    systemctl restart systemd-journal-upload
    timeout 15 bash -xec 'until systemctl -q is-active systemd-journal-remote.service; do sleep 1; done'
    systemctl status systemd-journal-{remote,upload}

    # It may take a bit until the whole journal is transferred
    timeout 30 bash -xec "until journalctl --directory=/var/log/journal/remote --identifier='$TEST_TAG' --grep='$TEST_MESSAGE'; do sleep 1; done"

    systemctl stop systemd-journal-upload
    systemctl stop systemd-journal-remote.{socket,service}

    # Let's test if journal-remote refuses connection from journal-upload with invalid client certs
    #
    # We should end up with something like this:
    #    systemd-journal-remote[726]: Client is not authorized
    #    systemd-journal-upload[738]: Upload to https://localhost:19532/upload failed with code 401:
    #    systemd[1]: systemd-journal-upload.service: Main process exited, code=exited, status=1/FAILURE
    #    systemd[1]: systemd-journal-upload.service: Failed with result 'exit-code'.
    #
    cat >/run/systemd/journal-upload.conf.d/99-test.conf <<EOB
    [Upload]
    URL=https://localhost:19532
    ServerKeyFile=/run/systemd/journal-remote-tls/key.pem
    ServerCertificateFile=/run/systemd/journal-remote-tls/cert.pem
    TrustedCertificateFile=/run/systemd/remote-pki/ca.crt
    EOB
    systemd-analyze cat-config systemd/journal-upload.conf
    mkdir -p /run/systemd/system/systemd-journal-upload.service.d
    cat >/run/systemd/system/systemd-journal-upload.service.d/99-test.conf <<EOB
    [Service]
    Restart=no
    EOB
    systemctl daemon-reload
    chgrp -R systemd-journal /run/systemd/journal-remote-tls
    chmod -R g+rwX /run/systemd/journal-remote-tls

    systemctl restart systemd-journal-upload
    timeout 10 bash -xec 'while [[ "$(systemctl show -P ActiveState systemd-journal-upload)" != failed ]]; do sleep 1; done'
    (! systemctl status systemd-journal-upload)
    EOF

}

1;
