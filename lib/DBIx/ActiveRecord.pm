package DBIx::ActiveRecord;

use 5.008008;
use strict;
use warnings;

use DBI;

our $VERSION = '0.01';

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
__END__
=head1 NAME

DBIx::ActiveRecord - rails3 ActiveRecord like O/R Mapper

=head1 SYNOPSIS

  define Model

    use DBIx::ActiveRecord::Model;
    package MyApp::Model::User;
    use base 'DBIx::ActiveRecord::Model';
    __PACKAGE__->table('users'); # table name is required

    # scope
    __PACKAGE__->default_scope(sub{ shift->eq(deleted => 0) });
    __PACKAGE__->scope(adult => sub{ shift->le(age => 20) });
    __PACKAGE__->scope(latest => sub{ shift->desc('created_at') });

    # association
    __PACKAGE__->belongs_to(group => 'MyApp::Model::Group');
    __PACKAGE__->has_many(posts => 'MyApp::Model::Post');

    1;

  initialize

    use DBIx::ActiveRecord;
    # same args for 'DBI::connect'
    DBIx::ActiveRecord->connect($data_source, $username, $auth, \%attr);

  basic CRUD

    # create
    my $user = MyApp::Model::User->new({name => 'new user'});
    $user->save;
    # or
    my $user = MyApp::Model::User->create({name => 'new user'});

    # update
    $user->name('change user name');
    $user->save;

    # delete
    $user->delete;

    # search
    my $users = MyApp::Model::User->in(id => [1..10])->eq(type => 2);

    # delete_all
    User->eq(deleted => 1)->delete_all;

    # update_all
    User->eq(type => 3)->update_all({deleted => 1});

  use scope and association

    my $user = MyApp::Model::User->adult->latest->first;
    my $group = $user->group;
    my $published_posts = $user->posts->eq(published => 1);
    my $drafts = $user->posts->eq(published => 0);

=head1 DESCRIPTION

Rails3 ActiveRecord like O/R Mapper module.
very light, dependenced module is DBI only and has most needs futures.

=head2 TODO

    mysql
    nested join and includes
    kaminari like pagenation

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

=head1 AUTHOR

Toshiyuki Saito

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Toshiyuki Saito

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
