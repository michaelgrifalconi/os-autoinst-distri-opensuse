from testapi import *

def run(self):
    assert_script_run('curl www3.zq1.de/test.txt')
    assert_script_run('rpm -q curl libcurl4')
