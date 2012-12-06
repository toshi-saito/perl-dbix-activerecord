package MyApp::Model::Post;
use base 'DBIx::ActiveRecord::Model';
use strict;
use warnings;

__PACKAGE__->table('posts');
__PACKAGE__->columns(qw/id category_id title content created_at updated_at/);
__PACKAGE__->primary_keys(qw/id/);

__PACKAGE__->belongs_to(category => 'MyApp::Model::Category');
__PACKAGE__->has_many(comments => 'MyApp::Model::Comment');

1;
