package DBIx::ActiveRecord;
use strict;
use warnings;

use DBI;

our $VERSION = 0.1;

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
    $self->_trace_sql;
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

sub debug {
    return if !$ENV{AR_TRACE_SQL};
    my $self = shift;
    my $method = shift;
    my $query = shift;
    my @binds = @_;
    $query =~ s/\?/my $v = shift(@binds);"'$v'";/eg;
    print STDERR "$method: $query\n";
}

sub _trace_sql {
    my $self = shift;
    return if !$ENV{AR_TRACE_SQL};
    no strict 'refs';
    no warnings 'redefine';

    my $execure_org = DBI::st->can('execute');
    *DBI::st::execute = sub {
        my $sth = shift;
        $self->debug('execute', $sth->{Statement}, @_);
        $execure_org->($sth, @_);
    };
}

sub dbh {$DBH}

sub transaction {
    my ($self, $coderef) = @_;
    $self->debug("begin_work", "");
    $self->dbh->begin_work;
    eval {$coderef->()};
    if ($@) {
      $self->debug("rollback", $@);
      $self->dbh->rollback
    } else {
      $self->debug("commit", $@);
      $self->dbh->commit;
    }
}

sub DESTROY {
    my ($self) = @_;
    $SINGLETON = undef;
    $self->dbh->disconnect if $self->dbh;
}

1;
