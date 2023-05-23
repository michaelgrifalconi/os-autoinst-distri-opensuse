from testapi import *


def run(self):

    script_run('ssh root@localhost')
    script_run('sleep 30')


def switch_to_root_console():
    send_key('ctrl-alt-f3')


def post_fail_hook(self):
    switch_to_root_console()
    assert_script_run('openqa-cli api experimental/search q=shutdown.pm')


def test_flags(self):
    return {'fatal': 1}