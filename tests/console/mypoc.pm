
use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console('root-console');
    #my $self = shift;
    #$self->select_serial_terminal;

    zypper_call("in vim",);
    

    #select_console "root-console";
}

1;
