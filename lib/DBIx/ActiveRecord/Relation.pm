package DBIx::ActiveRecord::Relation;
use strict;
use warnings;

use DBIx::ActiveRecord;
use DBIx::ActiveRecord::Scope;

sub new {
    my ($self, $model) = @_;
    bless {model => $model, arel => $model->arel}, $self;
}

sub scoped {
    my ($self) = @_;
    my $s = __PACKAGE__->new($self->{model});
    $s->{arel} = $self->{arel}->clone;
    $s;
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
    $s->($self->scoped, @_);
}

sub DESTROY{}

{
    no strict 'refs';
    no warnings 'redefine';

    *{__PACKAGE__."::all"} = sub {
        my $self = shift;
        $self->{cache}->{all} ||= DBIx::ActiveRecord::Scope::all($self, @_);
    };

    *{__PACKAGE__."::first"} = sub {
        my $self = shift;
        return $self->{cache}->{all}->[0] if $self->{cache}->{all};
        return $self->{cache}->{first} if exists $self->{cache}->{first};
        $self->{cache}->{first} = DBIx::ActiveRecord::Scope::first($self, @_);
    };

    *{__PACKAGE__."::last"} = sub {
        my $self = shift;
        return $self->{cache}->{all}->[-1] if $self->{cache}->{all};
        return $self->{cache}->{last} if exists $self->{cache}->{last};
        $self->{cache}->{last} = DBIx::ActiveRecord::Scope::last($self, @_);
    };
}

1;
