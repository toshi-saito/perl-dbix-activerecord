package DBIx::ActiveRecord;
use strict;
use warnings;

use DBI;

my $DBH;
my $SINGLETON;
our %GLOBAL;

sub connect {
    my ($self, $data_source, $user_name, $auth, $attr) = @_;
    $DBH = DBI->connect($data_source, $user_name, $auth, $attr);
    $SINGLETON = bless {dbh => $DBH}, $self;
    $self->init;
}

sub init {
    my $self = shift;
    foreach my $package (keys %GLOBAL) {
        $self->_load_model($package);
        $self->_load_fields($package);
        $self->_make_field_accessors($package);
    }
}

sub _load_model {
    my ($self, $package) = @_;
    my $file = $package;
    $file =~ s/::/\//;
    $file .= ".pm";
    eval {require $file};
}

sub _load_fields {
    my $self = shift;
    my $pkg = shift;
    my $sth = $self->dbh->prepare('DESCRIBE '.$pkg->table);
    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        push @{$pkg->_global->{columns}}, $row->{Field};
        push @{$pkg->_global->{primary_keys}}, $row->{Field} if $row->{Key} eq 'PRI';
    }
}

sub _make_field_accessors {
    my $self = shift;
    my $pkg = shift;
    no strict 'refs';
    foreach my $col (@{$pkg->_global->{columns}}) {
        *{$pkg."::$col"} = sub {
            my $self = shift;
            @_ ? $self->set_column($col, @_) : $self->get_column($col);
        };
    }
}

sub dbh {$DBH}

sub DESTROY {
    my ($self) = @_;
    $SINGLETON = undef;
    $self->dbh->disconnect if $self->dbh;
}

1;
