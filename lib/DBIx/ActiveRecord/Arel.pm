package DBIx::ActiveRecord::Arel;
use strict;
use warnings;
use Storable;

use DBIx::ActiveRecord::Arel::Column;
use DBIx::ActiveRecord::Arel::Where;
use DBIx::ActiveRecord::Arel::Join;
use DBIx::ActiveRecord::Arel::Order;
use DBIx::ActiveRecord::Arel::Value;
use DBIx::ActiveRecord::Arel::Native;
use DBIx::ActiveRecord::Arel::NakidWhere;

sub create {
    my ($self, $table_name) = @_;
    bless {
        table => $table_name,
        rels => {},
        wheres => [],
        joins => [],
        binds => [],
        selects => [],
        options => {},
    }, $self;
}

sub table {shift->{table}}
sub binds {@{shift->{binds}}}

sub to_sql {
    my ($self) = @_;

    $DBIx::ActiveRecord::Arel::Column::USE_FULL_NAME = $self->_has_join;

    my $sql = 'SELECT '.$self->_build_select.' FROM ' . $self->table;
    my $join = $self->_build_join;
    $sql .= ' '.$join if $join;
    my $where = $self->_build_where;
    $sql .= " WHERE $where" if $where;
    my $ops .= $self->_build_options;
    $sql .= " $ops" if $ops;
    $sql;
}

sub _has_join {
    my $self = shift;
    !!@{$self->{joins}};
}

sub _build_select {
    my ($self) = @_;
    my @select = map {$_->name} @{$self->{selects}};
    @select ? join(', ', @select) : $self->_col("*")->name;
}

sub _build_join {
    my ($self) = @_;
    my @join = map {$_->build} @{$self->{joins}};
    join(" ", @join);
}

sub _build_where {
    my ($self) = @_;
    my @binds;
    my @where;

    foreach my $w (@{$self->{wheres}}) {
        my ($where, $binds) = $w->build;
        push @where, $where;
        push @binds, @$binds if $binds;
    }

    $self->{binds} = \@binds;
    join(' AND ', @where);
}

sub _opts { shift->{options}}

sub _build_options {
    my $self = shift;
    my $ops = $self->_opts;

    my @sql;

    my $group = $self->_build_group;
    push @sql, 'GROUP BY '.$group if $group;

    my $order = $self->_build_order;
    push @sql, 'ORDER BY '.$order if $order;

    push @sql, 'LIMIT '.$ops->{limit} if $ops->{limit};
    push @sql, 'OFFSET '.$ops->{offset} if $ops->{offset};
    push @sql, 'FOR UPDATE' if $ops->{lock};
    join (' ', @sql);
}

sub _build_group {
    my $self = shift;
    my $g = $self->_opts->{group} || return;
    join(', ', map {$_->name} @$g);
}

sub _build_order {
    my $self = shift;
    my $order = $self->_opts->{order} || return;
    join(', ', map {$_->build} @$order);
}

sub clone {
    my $self = shift;
    Storable::dclone($self);
}

sub _col {
    my ($self, $name) = @_;
    $name = DBIx::ActiveRecord::Arel::Column->new($self, $name) if ref $name ne 'DBIx::ActiveRecord::Arel::Native';
    $name;
}

sub where {
    my $self = shift;
    my $statement = shift;
    my $o = $self->clone;
    $o->{wheres} ||= [];
    push @{$o->{wheres}}, DBIx::ActiveRecord::Arel::NakidWhere->new($statement, \@_);
    $o;
}

sub _add_where {
    my ($self, $operator, $key, $value) = @_;
    my $o = $self->clone;
    $o->{wheres} ||= [];
    $value = DBIx::ActiveRecord::Arel::Value->new($value) if ref $value ne 'DBIx::ActiveRecord::Arel::Native';
    push @{$o->{wheres}}, DBIx::ActiveRecord::Arel::Where->new($operator, $self->_col($key), $value);
    $o;
}

sub eq {
    my ($self, $key, $value) = @_;
    $self->_add_where('=', $key, $value);
}

sub ne {
    my ($self, $key, $value) = @_;
    $self->_add_where('!=', $key, $value);
}

sub in {
    my ($self, $key, $value) = @_;
    $self->_add_where('IN', $key, $value);
}

sub not_in {
    my ($self, $key, $value) = @_;
    $self->_add_where('NOT IN', $key, $value);
}

sub null {
    my ($self, $key) = @_;
    $self->_add_where('IS NULL', $key);
}

sub not_null {
    my ($self, $key) = @_;
    $self->_add_where('IS NOT NULL', $key);
}

sub gt {
    my ($self, $key, $value) = @_;
    $self->_add_where('>', $key, $value);
}

sub lt {
    my ($self, $key, $value) = @_;
    $self->_add_where('<', $key, $value);
}

sub ge {
    my ($self, $key, $value) = @_;
    $self->_add_where('>=', $key, $value);
}

sub le {
    my ($self, $key, $value) = @_;
    $self->_add_where('<=', $key, $value);
}

sub like {
    my ($self, $key, $value) = @_;
    $self->_add_where('LIKE', $key, $value);
}
sub contains {
    my ($self, $key, $value) = @_;
    $self->like($key, "%$value%");
}
sub starts_with {
    my ($self, $key, $value) = @_;
    $self->like($key, "$value%");
}
sub ends_with {
    my ($self, $key, $value) = @_;
    $self->like($key, "%$value");
}

sub between {
    my ($self, $key, $value1, $value2) = @_;
    $self->ge($key, $value1)->le($key, $value2);
}

# join
sub joins {
    my $self = shift;
    my $o = $self->clone;
    $o->{joins} ||= [];
    my $parent = $self;
    foreach my $arel (@_) {
        push @{$o->{joins}}, $parent->{rels}->{$arel->table};
        $parent = $arel;
    }
    $o;
}

# merge
sub merge {
    my ($self, $scope) = @_;
    my $o = $self->clone;
    my $s = $scope->clone;
    push @{$o->{wheres}}, @{$s->{wheres}};
    push @{$o->{selects}}, @{$s->{selects}};
    push @{$o->{options}->{group}}, @{$s->{options}->{group} || []};
    push @{$o->{options}->{order}}, @{$s->{options}->{order} || []};
    $o;
}

# select
sub select {
    my $self = shift;
    my $o = $self->clone;
    $o->{selects} ||= [];
    push @{$o->{selects}}, $self->_col($_) for @_;
    $o;
}

sub _set_opts {
    my ($self, $key, $value) = @_;
    my $o = $self->clone;
    $o->{options}->{$key} = $value;
    $o;
}

sub _add_opts {
    my ($self, $key, $value) = @_;
    my $o = $self->clone;
    $o->{options}->{$key} ||= [];
    push @{$o->{options}->{$key}}, $value;
    $o;
}

sub limit {
    my ($self, $limit) = @_;
    $self->_set_opts(limit => $limit);
}

sub offset {
    my ($self, $offset) = @_;
    $self->_set_opts(offset => $offset);
}

sub lock {
    my ($self) = @_;
    $self->_set_opts(lock => 1);
}

sub group {
    my $self = shift;
    my $o = $self;
    $o = $o->_add_opts(group => $o->_col($_)) for @_;
    $o;
}

sub asc {
    my $self = shift;
    my $o = $self;
    $o = $o->_add_opts(order => DBIx::ActiveRecord::Arel::Order->new('', $self->_col($_))) for @_;
    $o;
}

sub desc {
    my $self = shift;
    my $o = $self;
    $o = $o->_add_opts(order => DBIx::ActiveRecord::Arel::Order->new('DESC', $self->_col($_))) for @_;
    $o;
}

sub reorder {
    my $self = shift;
    $self->_set_opts(order => []);
}

sub reverse {
    my $self = shift;
    my $o = $self->clone;
    $_->reverse for @{$o->_opts->{order} || []};
    $o;
}

sub insert {
    my ($self, $hash, $columns) = @_;
    my @keys = $columns ? grep {exists $hash->{$_}} @$columns : keys %$hash;
    my $sql = 'INSERT INTO '.$self->table.' ('.join(', ', @keys).') VALUES ('.join(', ', map {'?'} @keys).')';
    $self->{binds} = [map {$hash->{$_}} @keys];
    $sql;
}

sub update {
    my ($self, $hash, $columns) = @_;
    $DBIx::ActiveRecord::Arel::Column::USE_FULL_NAME = 0;
    my @keys = $columns ? grep {exists $hash->{$_}} @$columns : keys %$hash;
    my @set = map {$_.' = ?'} @keys;
    my $sql = 'UPDATE '.$self->table.' SET '.join(', ', @set);
    my $where = $self->_build_where;
    $sql .= " WHERE $where" if $where;
    my @binds = map {$hash->{$_}} @keys;
    push @binds, @{$self->{binds}};
    $self->{binds} = \@binds;
    $sql;
}

sub delete {
    my ($self) = @_;
    $DBIx::ActiveRecord::Arel::Column::USE_FULL_NAME = 0;
    my $sql = 'DELETE FROM '.$self->table;
    my $where = $self->_build_where;
    $sql .= " WHERE $where" if $where;
    $sql;
}

sub count {
    my ($self) = @_;
    $DBIx::ActiveRecord::Arel::Column::USE_FULL_NAME = $self->_has_join;
    my $sql = 'SELECT COUNT(*) FROM '.$self->table;
    my $where = $self->_build_where;
    $sql .= " WHERE $where" if $where;
    $sql;
}

# relations
sub parent_relation {
    my ($self, $target, $opt) = @_;
    $self->{rels}->{$target->table} = DBIx::ActiveRecord::Arel::Join->new('INNER JOIN', $self->_col($opt->{foreign_key}), $target->_col($opt->{primary_key}));
}

sub child_relation {
    my ($self, $target, $opt) = @_;
    $self->{rels}->{$target->table} = DBIx::ActiveRecord::Arel::Join->new('LEFT JOIN', $self->_col($opt->{primary_key}), $target->_col($opt->{foreign_key}));
}
1;
