package DBIx::ActiveRecord::Scope;
use strict;
use warnings;

use base qw/Exporter/;

our @ISA = qw/Exporter/;
my @delegates = qw/eq ne in not_in null not_null gt lt ge le like contains starts_with ends_with between where select limit offset lock group asc desc reorder reverse/;
our @EXPORT = (@delegates, qw/scoped_instance _scope _execute merge joins includes _loads_includes update_all delete_all/);

{
    no strict 'refs';
    foreach my $m (@delegates) {
        *{__PACKAGE__."::$m"} = sub {
            my $self = shift;
            $self->_scope($m, @_);
        };
    }
}

sub _scope {
    my $self = shift;
    my $method = shift;
    my $s = $self->scoped;
    $s->{arel} = $s->{arel}->$method(@_);
    $s;
}

sub scoped_instance {
    my $self = shift;
    ref $self ? $self : $self->scoped;
}

sub update_all {
    my ($self, $sets) = @_;
    $self = $self->scoped;
    my $s = $self->{arel}->clone;
    my $sql = $s->update($sets);
    my $sth = $self->{model}->dbh->prepare($sql);
    $sth->execute($s->binds);
}

sub delete_all {
    my ($self) = @_;
    $self = $self->scoped;
    my $s = $self->{arel}->clone;
    my $sql = $s->delete;
    my $sth = $self->{model}->dbh->prepare($sql);
    $sth->execute($s->binds);
}

sub all {
    shift->_execute;
}

sub first {
    my $self = shift;
    my $s = $self->scoped_instance;
    my $org = $s->{arel}->clone;
    $s->{arel} = $s->{arel}->limit(1);
    my $r = $s->_execute;
    $s->{arel} = $org;
    @$r ? $r->[0] : undef;
}

sub last {
    my $self = shift;
    my $s = $self->scoped_instance;
    my $org = $s->{arel}->clone;
    $s->{arel} = $s->{arel}->limit(1)->reverse;
    my $r = $s->_execute;
    $s->{arel} = $org;
    @$r ? $r->[0] : undef;
}

sub _execute {
    my $self = shift;
    my $s = $self->scoped_instance;
    my $rs = $s->{model}->instantiates_by_relation($s);
    $s->_loads_includes($rs);
    $rs;
}

sub _loads_includes {
    my ($self, $rs) = @_;
    my $s = $self->scoped_instance;
    foreach my $opt (@{$s->{_includes}}) {
        my $model = $opt->{model};
        my $primary_key = $opt->{primary_key};
        my $foreign_key = $opt->{foreign_key};
        my %pkeys;
        map {$pkeys{$_->$primary_key} = 1} @$rs;
        next if !keys %pkeys;
        my $ir = $model->in($foreign_key => [keys %pkeys])->all;
        foreach my $r (@$rs) {
            my @r = grep {$r->$primary_key eq $_->$foreign_key} @$ir;
            if ($opt->{one}) {
                $r->{associates_cache}->{$opt->{name}} = $r[0];
            } else {
                my $s = $model->eq($foreign_key => $r->$primary_key);
                $s->{cache}->{all} = \@r;
                $r->{associates_cache}->{$opt->{name}} = $s;
            }
        }
    }
}

sub merge {
    my ($self, $relation) = @_;
    my $s = $self->scoped;
    $s->{arel} = $s->{arel}->merge($relation->{arel});
    $s;
}

sub joins {
    my ($self, $name) = @_;
    my $s = $self->scoped;
    my $model = $s->{model}->_global->{joins}->{$name} || die "no relation!";
    $s->{arel} = $s->{arel}->joins($model->_global->{arel});
    $s;
}

sub includes {
    my ($self, $name) = @_;
    my $s = $self->scoped;
    my $model = $s->{model}->_global->{joins}->{$name} || die "no relation!";
    my $opt = $s->{model}->_global->{includes}->{$name};
    $s->{_includes} ||= [];
    push @{$s->{_includes}}, {%$opt, model => $model, name => $name};
    $s;
}

1;
