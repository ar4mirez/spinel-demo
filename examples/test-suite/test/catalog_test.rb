# frozen_string_literal: true

require_relative "test_helper"

class CatalogTest < Minitest::Test
  include Fixtures

  def test_loads_products_from_the_fixture
    assert_equal %w[BOOK-RUBY MUG STICKERS], catalog.products.keys.sort
    mug = catalog.product("MUG")
    assert_equal "Spinel mug", mug.name
    assert_equal 1250, mug.price_cents
    assert mug.taxable, "products are taxable unless the catalog says otherwise"
    refute catalog.product("BOOK-RUBY").taxable
  end

  def test_coupon_codes_are_case_insensitive
    assert_equal 10, catalog.coupon("welcome10").percent_off
  end

  def test_unknown_coupon
    assert_raises(Cart::InvalidCoupon) { catalog.coupon("FREE") }
  end
end
