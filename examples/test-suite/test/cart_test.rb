# frozen_string_literal: true

require_relative "test_helper"

class CartTest < Minitest::Test
  include Fixtures

  def setup
    @cart = Cart.new(catalog, tax_rate_percent: 8)
  end

  def test_starts_empty
    assert_empty @cart
    assert_equal 0, @cart.total_cents
  end

  def test_add_counts_quantities
    @cart.add("MUG").add("MUG", 2).add("STICKERS")
    assert_equal 3, @cart.quantity("MUG")
    assert_equal 4, @cart.item_count
    refute_empty @cart
  end

  def test_add_rejects_unknown_products
    error = assert_raises(Cart::UnknownProduct) { @cart.add("NOPE") }
    assert_match(/unknown product: NOPE/, error.message)
  end

  def test_add_rejects_non_positive_quantities
    assert_raises(ArgumentError) { @cart.add("MUG", 0) }
  end

  def test_remove_some_or_all
    @cart.add("MUG", 3)
    @cart.remove("MUG", 1)
    assert_equal 2, @cart.quantity("MUG")
    @cart.remove("MUG")
    assert_empty @cart
  end

  def test_subtotal_and_tax_skip_untaxed_lines
    @cart.add("BOOK-RUBY").add("MUG", 2)
    assert_equal 3999 + 2500, @cart.subtotal_cents
    assert_equal 200, @cart.tax_cents # 8% of the mugs only
    assert_equal 6699, @cart.total_cents
  end

  def test_coupon_discounts_before_tax
    @cart.add("MUG", 2).apply_coupon("welcome10")
    assert_equal "WELCOME10", @cart.coupon.code
    assert_equal 250, @cart.discount_cents
    assert_equal 180, @cart.tax_cents
    assert_equal 2430, @cart.total_cents
  end

  def test_coupon_minimum_subtotal
    @cart.add("STICKERS")
    error = assert_raises(Cart::InvalidCoupon) { @cart.apply_coupon("BIG25") }
    assert_equal "BIG25 needs a subtotal of at least $100.00", error.message
    assert_nil @cart.coupon
  end

  def test_receipt
    @cart.add("BOOK-RUBY").add("STICKERS", 2)
    receipt = @cart.receipt
    assert_includes receipt, "The Ruby Book"
    assert_match(/^Total\s+\$50\.77$/, receipt)
  end

  def test_format
    assert_equal "$0.05", Cart.format(5)
    assert_equal "$12.50", Cart.format(1250)
    assert_equal "-$1.00", Cart.format(-100)
  end
end
