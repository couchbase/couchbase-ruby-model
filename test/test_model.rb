# Author:: Couchbase <info@couchbase.com>
# Copyright:: 2011, 2012 Couchbase, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.join(File.dirname(__FILE__), 'setup')

class Post < Couchbase::Model
  attribute :title
  attribute :body
end

class TestModel < MiniTest::Unit::TestCase

  def setup
    @mock = start_mock
    Post.bucket = Couchbase.connect(:hostname => @mock.host,
                                    :port => @mock.port)
  end

  def teardown
    stop_mock(@mock)
  end

  def test_assigns_attributes_from_the_hash
    post = Post.new(:title => "Hello, world")
    assert_equal "Hello, world", post.title
    refute post.body
    refute post.id
  end

  def test_assings_id_and_saves_the_object
    post = Post.create(:title => "Hello, world")
    assert post.id
  end

  def test_updates_attributes
    post = Post.create(:title => "Hello, world")
    post.update(:body => "This is my first example")
    assert_equal "This is my first example", post.body
  end

  def test_refreshes_the_attributes_with_reload_method
    orig = Post.create(:title => "Hello, world")
    double = Post.find(orig.id)
    double.update(:title => "Good bye, world")
    orig.reload
    assert_equal "Good bye, world", orig.title
  end

  def test_doesnt_raise_if_the_attribute_redefined
    eval <<-EOC
      class RefinedPost < Couchbase::Model
        attribute :title
        attribute :title
      end
    EOC
  end

  def test_allows_to_define_several_attributes_at_once
    eval <<-EOC
      class Comment < Couchbase::Model
        attribute :name, :email, :body
      end
    EOC

    comment = Comment.new
    assert comment.respond_to?(:name)
    assert comment.respond_to?(:email)
    assert comment.respond_to?(:body)
  end

  def test_allows_arbitrary_ids
    Post.create(:id => uniq_id, :title => "Foo")
    assert_equal "Foo", Post.find(uniq_id).title
  end

  def test_returns_an_instance_of_post
    Post.bucket.set(uniq_id, {:title => 'foo'})
    assert Post.find(uniq_id).kind_of?(Post)
    assert_equal uniq_id, Post.find(uniq_id).id
    assert_equal "foo", Post.find(uniq_id).title
  end

  def test_changes_its_attributes
    post = Post.create(:title => "Hello, world")
    post.title = "Good bye, world"
    post.save.reload
    assert_equal "Good bye, world", post.title
  end

  def test_assings_a_new_id_to_each_record
    post1 = Post.create
    post2 = Post.create

    refute post1.new?
    refute post2.new?
    refute_equal post1.id, post2.id
  end

  def test_deletes_an_existent_model
    post = Post.create(:id => uniq_id)
    assert post.delete
    refute Post.bucket.get(uniq_id)
  end

  def test_fails_to_delete_model_without_id
    post = Post.new(:title => "Hello")
    refute post.id
    assert_raises Couchbase::Error::MissingId do
      post.delete
    end
  end

end
