package DBIx::ActiveRecord::Relation;
use strict;
use warnings;

use DBIx::ActiveRecord;
use DBIx::ActiveRecord::Scope;

sub new {
    my ($self, $model) = @_;
    bless {model => $model, arel => $model->arel}, $self;
}

sub to_sql {shift->{arel}->to_sql}
sub _binds {shift->{arel}->binds}

sub update {
    my ($self, $sets) = @_;
    my $s = $self->{arel}->clone;
    my $sql = $s->update($sets);
    my $sth = $self->{model}->dbh->prepare($sql);
    $sth->execute($s->binds);
}

sub delete {
    my ($self) = @_;
    my $s = $self->{arel}->clone;
    my $sql = $s->delete;
    my $sth = $self->{model}->dbh->prepare($sql);
    $sth->execute($s->binds);
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ /([^:]+)$/;
    my $m = $1;
    my $s = $self->{model}->_global->{scopes}->{$m};
    die "method missing $AUTOLOAD" if !$s;
    $s->($self->_scoped, @_);
}

sub DESTROY{}


1;
