from testapi import *


def run(self):

    ensure_installed("flatpak")

    assert_script_run('flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo')
    assert_script_run('flatpak install -y com.obsproject.Studio', timeout => 300)
    x11_start_program('obs', match_timeout => 60)
    # # sometimes send_key "alt-f4" doesn't work reliable, so repeat it and exit
    # send_key_until_needlematch 'generic-desktop', "alt-f4", 6, 5;


def switch_to_root_console():
    send_key('ctrl-alt-f3')


def post_fail_hook(self):
    switch_to_root_console()
    assert_script_run('openqa-cli api experimental/search q=shutdown.pm')


def test_flags(self):
    return {'fatal': 1}