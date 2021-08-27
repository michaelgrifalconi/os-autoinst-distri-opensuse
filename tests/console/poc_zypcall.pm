# POC Not to be used

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console('root-console');
    zypper_call('in python');
    zypper_call('in php');
    zypper_call('in rabbitmq-server');
    zypper_call('in apache2');
}

1;



