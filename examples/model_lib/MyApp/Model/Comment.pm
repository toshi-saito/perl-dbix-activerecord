package MyApp::Model::Comment;
use base 'DBIx::ActiveRecord::Model';
use strict;
use warnings;

__PACKAGE__->table('comments');
__PACKAGE__->columns(qw/id post_id content created_at/);
__PACKAGE__->primary_keys(qw/id/);

__PACKAGE__->belongs_to(post => 'MyApp::Model::Post');

1;
