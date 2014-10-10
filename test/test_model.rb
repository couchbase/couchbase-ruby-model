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
  attribute :author, :default => 'Anonymous'
  attribute :created_at, :default => lambda { Time.utc('2010-01-01') }
end

class ValidPost < Couchbase::Model
  attribute :title

  def valid?
    title && !title.empty?
  end
end

class Brewery < Couchbase::Model
  attribute :name
end

class Beer < Couchbase::Model
  attribute :name
  belongs_to :brewery
end

class Wine < Couchbase::Model
  attribute :name
  belongs_to :winery, :class_name => :Brewery
end

class Attachment < Couchbase::Model
  defaults :format => :plain
end

class Comments < Couchbase::Model
  include Enumerable
  attribute :comments, :default => []
end

class User < Couchbase::Model
  design_document :people
end

class TestModel < MiniTest::Unit::TestCase

  def setup
    @mock = start_mock
    bucket = Couchbase.connect(:hostname => @mock.host, :port => @mock.port)
    [Post, ValidPost, Brewery, Beer, Attachment, Wine].each do |model|
      model.bucket = bucket
    end
  end

  def teardown
    stop_mock(@mock)
  end

  def test_design_document
    assert_equal 'people', User.design_document
    assert_equal 'new_people', User.design_document('new_people')
    assert_equal 'post', Post.design_document
  end

  def test_it_supports_value_property
    doc = {
      'id' => 'x',
      'key' => 'x',
      'value' => 'x',
      'doc' => {
        'value' => {'title' => 'foo'}
      }
    }
    post = Post.wrap(Post.bucket, doc)
    assert_equal 'foo', post.title
  end

  def test_it_supports_json_property
    doc = {
      'id' => 'x',
      'key' => 'x',
      'value' => 'x',
      'doc' => {
        'json' => {'title' => 'foo'}
      }
    }
    post = Post.wrap(Post.bucket, doc)
    assert_equal 'foo', post.title
  end

  def test_access_attribute_by_key
    post = Post.new(:title => 'Hello, world')
    assert_equal 'Hello, world', post[:title]
  end

  def test_update_attribute_by_key
    post = Post.new(:title => 'Hello, world')
    post[:title] = 'world, Hello'
    assert_equal 'world, Hello', post.title
  end

  def test_assigns_attributes_from_the_hash
    post = Post.new(:title => 'Hello, world')
    assert_equal 'Hello, world', post.title
    refute post.body
    refute post.id
  end

  def test_uses_default_value_or_nil
    post = Post.new(:title => 'Hello, world')
    refute post.body
    assert_equal 'Anonymous', post.author
    assert_equal 'Anonymous', post.attributes[:author]
  end

  def test_allows_lambda_as_default_value
    post = Post.new(:title => 'Hello, world')
    expected = Time.utc('2010-01-01')
    assert_equal expected, post.created_at
    assert_equal expected, post.attributes[:created_at]
  end

  def test_assings_id_and_saves_the_object
    post = Post.create(:title => 'Hello, world')
    assert post.id
  end

  def test_updates_attributes
    post = Post.create(:title => 'Hello, world')
    post.update(:body => 'This is my first example')
    assert_equal 'This is my first example', post.body
  end

  def test_update_attributes_saves_record
    post = Post.new

    assert !post.persisted?, 'Post already persisted'
    post.update_attributes(:title => 'Hello, world', :body => "How's it going?")
    assert post.persisted?,  'Post not persisted'

    assert_equal "How's it going?", post.body
    assert_equal "Hello, world",    post.title
  end

  def test_refreshes_the_attributes_with_reload_method
    orig = Post.create(:title => 'Hello, world')
    double = Post.find(orig.id)
    double.update(:title => 'Good bye, world')
    orig.reload
    assert_equal 'Good bye, world', orig.title
  end

  def test_reloads_cas_value_with_reload_method
    orig = Post.create(:title => "Hello, world")
    double = Post.find(orig.id)
    orig.update(:title => "Good bye, world")
    double.reload

    assert_equal orig.meta[:cas], double.meta[:cas]
  end

  def test_it_raises_not_found_exception
    assert_raises Couchbase::Error::NotFound do
      Post.find('missing_key')
    end
  end

  def test_it_raises_not_found_exception_if_id_is_nil
    assert_raises Couchbase::Error::NotFound do
      Post.find(nil)
    end
  end

  def test_it_returns_nil_when_key_not_found
     refute Post.find_by_id('missing_key')
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
    assert_respond_to comment, :name
    assert_respond_to comment, :email
    assert_respond_to comment, :body
  end

  def test_allows_arbitrary_ids
    Post.create(:id => uniq_id, :title => 'Foo')
    assert_equal 'Foo', Post.find(uniq_id).title
  end

  def test_returns_an_instance_of_post
    Post.bucket.set(uniq_id, {:title => 'foo'})
    assert Post.find(uniq_id).kind_of?(Post)
    assert_equal uniq_id, Post.find(uniq_id).id
    assert_equal 'foo', Post.find(uniq_id).title
  end

  def test_changes_its_attributes
    post = Post.create(:title => 'Hello, world')
    post.title = 'Good bye, world'
    post.save.reload
    assert_equal 'Good bye, world', post.title
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
    assert_raises Couchbase::Error::NotFound do
      Post.bucket.get(uniq_id)
    end
  end

  def test_destroy_an_existing_model
    post = Post.create(:id => uniq_id)
    assert post.destroy
    assert_raises Couchbase::Error::NotFound do
      Post.bucket.get(uniq_id)
    end
  end

  def test_belongs_to_with_class_name_assoc
    brewery = Brewery.create(:name => "R Wines")
    assert_includes Wine.attributes.keys, :winery_id
    wine = Wine.create(:name => "Classy", :winery_id => brewery.id)
    assert_respond_to wine, :winery
    assoc = wine.winery
    assert_instance_of Brewery, assoc
    assert_equal "R Wines", assoc.name
  end

  def test_fails_to_delete_model_without_id
    post = Post.new(:title => 'Hello')
    refute post.id
    assert_raises Couchbase::Error::MissingId do
      post.delete
    end
  end

  def test_belongs_to_assoc
    brewery = Brewery.create(:name => 'Anheuser-Busch')
    assert_includes Beer.attributes.keys, :brewery_id
    beer = Beer.create(:name => 'Budweiser', :brewery_id => brewery.id)
    assert_respond_to beer, :brewery
    assoc = beer.brewery
    assert_instance_of Brewery, assoc
    assert_equal 'Anheuser-Busch', assoc.name
  end

  def test_belongs_to_assoc_assign
    brewery = Brewery.create(:name => 'Anheuser-Busch')
    beer = Beer.create(:name => 'Budweiser')
    beer.brewery = brewery

    assert_equal brewery.id, beer.brewery_id
    assert_equal brewery, beer.brewery

    beer.brewery = nil
    assert_nil beer.brewery
    assert_nil beer.brewery_id
  end

  def test_to_key
    assert_equal ['the-id'], Post.new(:id => 'the-id').to_key
    assert_equal ['the-key'], Post.new(:key => 'the-key').to_key
  end

  def test_to_param
    assert_equal 'the-id', Post.new(:id => 'the-id').to_param
    assert_equal 'the-key', Post.new(:key => ['the', 'key']).to_param
  end

  def test_as_json
    require 'active_support/json/encoding'

    response = {'id' => 'the-id'}
    assert_equal response, Post.new(:id => 'the-id').as_json

    response = {}
    assert_equal response, Post.new(:id => 'the-id').as_json(:except => :id)
  end

  def test_validation
    post = ValidPost.create(:title => 'Hello, World!')
    assert post.valid?, 'post with title should be valid'
    post.title = nil
    refute post.save
    assert_raises(Couchbase::Error::RecordInvalid) do
      post.save!
    end
    refute ValidPost.create(:title => nil)
    assert_raises(Couchbase::Error::RecordInvalid) do
      ValidPost.create!(:title => nil)
    end
  end

  def test_blob_documents
    contents = File.read(__FILE__)
    id = Attachment.create(:raw => contents).id
    blob = Attachment.find(id)
    assert_equal contents, blob.raw
  end

  def test_couchbase_ancestor
    assert_equal Couchbase::Model, Comments.couchbase_ancestor
  end

  def test_returns_multiple_instances_of_post
    Post.create(:id => uniq_id('first'), :title => 'foo')
    Post.create(:id => uniq_id('second'), :title => 'bar')

    results = Post.find([uniq_id('first'), uniq_id('second')])
    assert results.kind_of?(Array)
    assert results.size == 2
    assert results.detect { |post| post.id == uniq_id('first') }.title == 'foo'
    assert results.detect { |post| post.id == uniq_id('second') }.title == 'bar'
  end

  def test_returns_array_for_array_of_ids
    Post.create(:id => uniq_id('first'), :title => 'foo')

    results = Post.find([uniq_id('first')])
    assert results.kind_of?(Array)
    assert results.size == 1
    assert results[0].title == 'foo'
  end

  def test_returns_array_for_array_of_ids_using_find_by_id
    Post.create(:id => uniq_id('first'), :title => 'foo')

    results = Post.find_by_id([uniq_id('first')])
    assert results.kind_of?(Array)
    assert results.size == 1
    assert results[0].title == 'foo'
  end
end
