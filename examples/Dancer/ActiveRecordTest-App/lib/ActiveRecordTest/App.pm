package ActiveRecordTest::App;
use Dancer ':syntax';
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../../lib/";
use lib "$FindBin::Bin/../../../model_lib/";

use MyApp::Model::Category;
use MyApp::Model::Post;
use MyApp::Model::Comment;

use DBIx::ActiveRecord;
DBIx::ActiveRecord->connect("dbi:mysql:activerecord_test", "root", "root");

our $VERSION = '0.1';

# helper
use constant Category => 'MyApp::Model::Category';
use constant Post => 'MyApp::Model::Post';
use constant Comment => 'MyApp::Model::Comment';


# category list
# add category
# post list
# post detail - add comment
# create post
# delete post

get '/' => sub {
    my $categories = Category->includes('posts')->all;
    template 'index', {categories => $categories};
};

post '/add_category' => sub {
    Category->create({name => params->{name} || 'no name'});
    redirect '/';
};

get '/new_post' => sub {
    my $categories = Category->all;
    my $category = Category->eq(id => params->{cid})->first;
    template 'new_post', {categories => $categories, category => $category};
};

post '/add_post' => sub {
    Post->create({
        category_id => params->{category_id},
        title => params->{title} || 'no title',
        content => params->{content},
    });
    redirect '/';
};

get '/post' => sub {
    my $categories = Category->all;
    my $post = Post->eq(id => params->{id})->first;
    template 'post', {categories => $categories, post => $post};
};

post '/add_comment' => sub {
    Comment->create({
      post_id => params->{post_id},
      content => params->{content},
    });
    redirect "/post?id=".params->{post_id};
};

get '/category' => sub {
    my $categories = Category->all;
    my $category = Category->eq(id => params->{cid})->first;
    template 'category', {categories => $categories, category => $category};
};

true;
