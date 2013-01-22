# Couchbase Model

This library allows to declare models for [couchbase gem][1].

## SUPPORT

If you found an issue, please file it in our [JIRA][3]. Also you are
always welcome on `#libcouchbase` channel at [freenode.net IRC servers][4].

Documentation: [http://rdoc.info/gems/couchbase-model](http://rdoc.info/gems/couchbase-model)

## Rails integration

To generate config you can use `rails generate couchbase:config`:

    $ rails generate couchbase:config
    create  config/couchbase.yml

It will generate this `config/couchbase.yml` for you:

    common: &common
      hostname: localhost
      port: 8091
      username:
      password:
      pool: default

    development:
      <<: *common
      bucket: couchbase_tinyurl_development

    test:
      <<: *common
      bucket: couchbase_tinyurl_test

    # set these environment variables on your production server
    production:
      hostname: <%= ENV['COUCHBASE_HOST'] %>
      port: <%= ENV['COUCHBASE_PORT'] %>
      username: <%= ENV['COUCHBASE_USERNAME'] %>
      password: <%= ENV['COUCHBASE_PASSWORD'] %>
      pool: <%= ENV['COUCHBASE_POOL'] %>
      bucket: <%= ENV['COUCHBASE_BUCKET'] %>

## Examples

    require 'couchbase/model'

    class Post < Couchbase::Model
      attribute :title
      attribute :body
      attribute :draft
    end

    p = Post.new(:id => 'hello-world',
                 :title => 'Hello world',
                 :draft => true)
    p.save
    p = Post.find('hello-world')
    p.body = "Once upon the times...."
    p.save
    p.update(:draft => false)
    Post.bucket.get('hello-world')  #=> {"title"=>"Hello world", "draft"=>false,
                                    #    "body"=>"Once upon the times...."}

You can also let the library generate the unique identifier for you:

    p = Post.create(:title => 'How to generate ID',
                    :body => 'Open up the editor...')
    p.id        #=> "74f43c3116e788d09853226603000809"

There are several algorithms available. By default it use `:sequential`
algorithm, but you can change it to more suitable one for you:

    class Post < Couchbase::Model
      attribute :title
      attribute :body
      attribute :draft

      uuid_algorithm :random
    end

You can define connection options on per model basis:

    class Post < Couchbase::Model
      attribute :title
      attribute :body
      attribute :draft

      connect :port => 80, :bucket => 'blog'
    end

## Validations

There are all methods from ActiveModel::Validations accessible in
context of rails application:

    class Comment < Couchbase::Model
      attribute :author, :body

      validates_presence_of :author, :body
    end

## Views (aka Map/Reduce indexes)

Views are stored in models directory in subdirectory named after the
model (to be precious `design_document` attribute of the model class).
Here is an example of directory layout for `Link` model with three
views.

    .
    └── app
        └── models
            ├── link
            │   ├── total_count
            │   │   ├── map.js
            │   │   └── reduce.js
            │   ├── by_created_at
            │   │   └── map.js
            │   └── by_view_count
            │       └── map.js
            └── link.rb

To generate view you can use yet another generator `rails generate
couchbase:view DESIGNDOCNAME VIEWNAME`. For example how `total_count`
view could be generated:

    $ rails generate couchbase:view link total_count

The generated files contains useful info and links about how to write
map and reduce functions, you can take a look at them in the [templates
directory][2].

In the model class you should declare accessible views:

    class Post < Couchbase::Model
      attribute :title
      attribute :body
      attribute :draft
      attribute :view_count
      attribute :created_at, :default => lambda { Time.now }

      view :total_count, :by_created_at, :by_view_count
    end

And request them later:

    Post.by_created_at(:include_docs => true).each do |post|
      puts post.title
    end

    Post.by_view_count(:include_docs => true).group_by(&:view_count) do |count, posts|
      p "#{count} -> #{posts.map{|pp| pp.inspect}.join(', ')}"
    end


[1]: https://github.com/couchbase/couchbase-ruby-client/
[2]: https://github.com/couchbase/couchbase-ruby-model/blob/master/lib/rails/generators/couchbase/view/templates/
[3]: http://couchbase.com/issues/browse/RCBC
[4]: http://freenode.net/irc_servers.shtml
