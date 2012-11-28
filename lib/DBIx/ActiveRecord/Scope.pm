package DBIx::ActiveRecord::Scope;
use strict;
use warnings;

use base qw/Exporter/;

our @ISA = qw/Exporter/;
my @delegates = qw/eq ne in not_in null not_null gt lt ge le like contains starts_with ends_with between where select limit offset lock group asc desc reorder reverse/;
our @EXPORT = (@delegates, qw/_scoped _scope merge all joins first last/);

{
    no strict 'refs';
    foreach my $m (@delegates) {
        *{__PACKAGE__."::$m"} = sub {
            my $self = shift;
            $self->_scope($m, @_);
        };
    }
}

sub _scoped {
    my $self = shift;
    ref $self ? $self : $self->scoped;
}

sub _scope {
    my $self = shift;
    my $method = shift;
    my $s = $self->_scoped;
    $s->{arel} = $s->{arel}->$method(@_);
    $s;
}

sub merge {
    my ($self, $relation) = @_;
    my $s = $self->_scoped;
    $s->{arel} = $s->{arel}->merge($relation->{arel});
    $s;
}

sub all {
    my $self = shift;
    my $s = $self->_scoped;
    $s->{model}->instantiates_by_relation($s);
}

sub first {
    my $self = shift;
    my $r = $self->limit(1)->all;
    @$r ? $r->[0] : undef;
}

sub last {
    my $self = shift;
    my $r = $self->limit(1)->reverse->all;
    @$r ? $r->[0] : undef;
}

sub joins {
    my ($self, $name) = @_;
    my $s = $self->_scoped;
    my $model = $s->{model}->_global->{joins}->{$name} || die "no relation!";
    $s->{arel} = $s->{arel}->joins($model->_global->{arel});
    $s;
}
1;
