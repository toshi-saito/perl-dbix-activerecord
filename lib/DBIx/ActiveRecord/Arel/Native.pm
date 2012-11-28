package DBIx::ActiveRecord::Arel::Native;
use strict;
use warnings;

sub new {
    my ($self, $func) = @_;
    bless {func => $func}, $self;
}

sub name {
    shift->{func};
}

sub is_native {1}

1;
