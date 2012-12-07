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

class Program < Couchbase::Model
  attribute :title
  attribute :genres, :default => []
end

class Movie < Program
  attribute :mpaa_rating
  attribute :runtime
end

class Series < Program
  attribute :vchip_rating
end

class Episode < Series
  attribute :runtime
end

class TestModelRailsIntegration < MiniTest::Unit::TestCase

  def test_class_attributes_are_inheritable
    program_attributes = [:title, :genres]
    movie_attributes   = [:mpaa_rating, :runtime]
    series_attributes  = [:vchip_rating]
    episode_attributes = [:runtime]

    assert_equal program_attributes, Program.attributes.keys
    assert_equal program_attributes + movie_attributes, Movie.attributes.keys
    assert_equal program_attributes + series_attributes, Series.attributes.keys
    assert_equal program_attributes + series_attributes + episode_attributes, Episode.attributes.keys
  end

  def test_default_attributes_are_inheritable
    assert_equal nil, Movie.attributes[:title]
    assert_equal [],  Movie.attributes[:genres]
  end

  def test_instance_attributes_are_inheritable
    episode = Episode.new(:title => 'Family Guy', :genres => ['Comedy'], :vchip_rating => 'TVPG', :runtime => 30)

    assert_equal [:title, :genres, :vchip_rating, :runtime], episode.attributes.keys
    assert_equal 'Family Guy', episode.title
    assert_equal ['Comedy'], episode.genres
    assert_equal 30, episode.runtime
    assert_equal 'TVPG', episode.vchip_rating
  end

  def test_class_attributes_from_subclasses_do_not_propogate_up_ancestor_chain
    assert_equal [:title, :genres, :vchip_rating], Series.attributes.keys
  end

  def test_instance_attributes_from_subclasses_do_not_propogate_up_ancestor_chain
    series = Series.new(:title => 'Family Guy', :genres => ['Comedy'], :vchip_rating => 'TVPG')
    assert_equal [:title, :genres, :vchip_rating], series.attributes.keys
  end

end
