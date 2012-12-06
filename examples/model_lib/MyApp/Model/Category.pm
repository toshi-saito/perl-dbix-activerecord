package MyApp::Model::Category;
use base 'DBIx::ActiveRecord::Model';
use strict;
use warnings;

__PACKAGE__->table('categories');
__PACKAGE__->columns(qw/id name created_at/);
__PACKAGE__->primary_keys(qw/id/);

__PACKAGE__->has_many(posts => 'MyApp::Model::Post');

1;
