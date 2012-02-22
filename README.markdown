# Couchbase Model

This library allows to declare models for [couchbase gem][1]. Here are example:

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

[1]: https://github.com/couchbase/couchbase-ruby-client/
