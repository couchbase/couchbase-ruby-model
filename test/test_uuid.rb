require File.join(File.dirname(__FILE__), 'setup')

class TestUUID < MiniTest::Unit::TestCase

  def test_it_can_generate_10k_unique_ids
    random = Couchbase::Model::UUID.new.next(10_000, :random)
    assert_equal 10_000, random.uniq.size

    utc_random = Couchbase::Model::UUID.new.next(10_000, :utc_random)
    assert_equal 10_000, utc_random.uniq.size

    sequential = Couchbase::Model::UUID.new.next(10_000, :sequential)
    assert_equal 10_000, sequential.uniq.size
  end

  def test_it_produces_monotonically_increasing_ids
    utc_random = Couchbase::Model::UUID.new
    assert utc_random.next(1, :utc_random) < utc_random.next(1, :utc_random)

    sequential = Couchbase::Model::UUID.new
    assert sequential.next(1, :sequential) < sequential.next(1, :sequential)
  end

  def test_it_roll_over
    generator = Couchbase::Model::UUID.new
    prefix = generator.next[0, 26]
    n = 0
    n += 1 while prefix == generator.next[0, 26]
    assert(n >= 5000 && n <= 11000)
  end

end
