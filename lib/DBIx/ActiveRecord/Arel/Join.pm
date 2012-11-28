package DBIx::ActiveRecord::Arel::Join;
use strict;
use warnings;

sub new {
    my ($self, $join_type, $rel_column, $dest_column) = @_;
    bless {type => $join_type, rel => $rel_column, dest => $dest_column}, $self;
}

sub build {
    my $self = shift;
    $self->{type}.' '.$self->{dest}->table->table.' ON '.$self->{dest}->name.' = '.$self->{rel}->name;
}

1;
