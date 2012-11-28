package DBIx::ActiveRecord::Arel::Value;
use strict;
use warnings;

sub new {
    my ($self, $value) = @_;
    bless {value => $value}, $self;
}

sub name {
    shift->{value};
}

sub is_native {0}

1;
