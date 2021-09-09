# POC Not to be used

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    #my ($self) = @_;
    #select_console('root-console');
    my $self = shift;
    $self->select_serial_terminal;

    my @a = (1..9);
    for my $i (@a){
        zypper_call('in python');
        zypper_call('in php');
        zypper_call('in rabbitmq-server');
        zypper_call('in apache2');

        zypper_call('rm python');
        zypper_call('rm php');
        zypper_call('rm rabbitmq-server');
        zypper_call('rm apache2');
    }
}

1;



