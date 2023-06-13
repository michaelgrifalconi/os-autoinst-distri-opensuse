from testapi import *

def run(self):

    perl.require("serial_terminal")
    perl.require("utils")
    perl.require("x11utils")
    #ensure_installed("flatpak")
    perl.serial_terminal.select_serial_terminal()
    perl.utils.zypper_call("in flatpak")

    assert_script_run("flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo")
    assert_script_run("flatpak install -y com.obsproject.Studio",300)
    #assert_script_run("flatpak install -y com.obsproject.Studio", timeout=300) DOES NOT WORK

    select_console('x11')
    perl.x11utils.x11_start_program("flatpak run com.obsproject.Studio", 30, 1, "flatpak-obsproject")
    # sometimes send_key "alt-f4" doesn't work reliable, so repeat it and exit
    send_key_until_needlematch("generic-desktop", "alt-f4", 6, 5)


def switch_to_root_console():
    send_key('ctrl-alt-f3')


def post_fail_hook(self):
    switch_to_root_console()
    assert_script_run('openqa-cli api experimental/search q=shutdown.pm')


def test_flags(self):
    return {'fatal': 1}