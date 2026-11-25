# frozen_string_literal: true

require "yaml"

# A shopping cart priced in whole cents, so no floating-point rounding creeps
# into totals. Products and coupons come from a YAML catalog.
class Cart
  class Error < StandardError; end
  class UnknownProduct < Error; end
  class InvalidCoupon < Error; end

  Product = Struct.new(:sku, :name, :price_cents, :taxable, keyword_init: true)
  Coupon = Struct.new(:code, :percent_off, :min_subtotal_cents, keyword_init: true)

  # A catalog of products and coupons, loaded from a YAML file such as
  # fixtures/catalog.yml.
  class Catalog
    attr_reader :products, :coupons

    def self.load(path)
      data = YAML.safe_load(File.read(path))
      products = data.fetch("products").map do |sku, attrs|
        Product.new(sku: sku, name: attrs.fetch("name"),
                    price_cents: attrs.fetch("price_cents"),
                    taxable: attrs.fetch("taxable", true))
      end
      coupons = data.fetch("coupons", {}).map do |code, attrs|
        Coupon.new(code: code, percent_off: attrs.fetch("percent_off"),
                   min_subtotal_cents: attrs.fetch("min_subtotal_cents", 0))
      end
      new(products, coupons)
    end

    def initialize(products, coupons = [])
      @products = products.to_h { |p| [p.sku, p] }
      @coupons = coupons.to_h { |c| [c.code, c] }
    end

    def product(sku)
      @products.fetch(sku) { raise UnknownProduct, "unknown product: #{sku}" }
    end

    def coupon(code)
      @coupons.fetch(code.upcase) { raise InvalidCoupon, "unknown coupon: #{code}" }
    end
  end

  attr_reader :coupon

  def initialize(catalog, tax_rate_percent: 0)
    @catalog = catalog
    @tax_rate_percent = tax_rate_percent
    @lines = Hash.new(0)
    @coupon = nil
  end

  def add(sku, quantity = 1)
    raise ArgumentError, "quantity must be positive, got #{quantity}" unless quantity.positive?

    @catalog.product(sku)
    @lines[sku] += quantity
    self
  end

  def remove(sku, quantity = nil)
    return self unless @lines.key?(sku)

    if quantity.nil? || quantity >= @lines[sku]
      @lines.delete(sku)
    else
      @lines[sku] -= quantity
    end
    self
  end

  def quantity(sku) = @lines.fetch(sku, 0)
  def item_count = @lines.values.sum
  def empty? = @lines.empty?

  def apply_coupon(code)
    coupon = @catalog.coupon(code)
    if subtotal_cents < coupon.min_subtotal_cents
      raise InvalidCoupon, "#{coupon.code} needs a subtotal of at least #{Cart.format(coupon.min_subtotal_cents)}"
    end

    @coupon = coupon
    self
  end

  def subtotal_cents
    @lines.sum { |sku, qty| @catalog.product(sku).price_cents * qty }
  end

  def discount_cents
    return 0 unless @coupon

    (subtotal_cents * @coupon.percent_off / 100.0).round
  end

  # Tax is charged on taxable lines after the coupon, which is spread over
  # every line in proportion to its price.
  def tax_cents
    return 0 if subtotal_cents.zero?

    taxable = @lines.sum do |sku, qty|
      product = @catalog.product(sku)
      product.taxable ? product.price_cents * qty : 0
    end
    taxable_after_discount = taxable - (discount_cents * taxable / subtotal_cents.to_f)
    (taxable_after_discount * @tax_rate_percent / 100.0).round
  end

  def total_cents = subtotal_cents - discount_cents + tax_cents

  def receipt
    lines = @lines.map do |sku, qty|
      product = @catalog.product(sku)
      format("%-20s %3d x %8s %9s", product.name, qty,
             Cart.format(product.price_cents), Cart.format(product.price_cents * qty))
    end
    lines << format("%-36s %9s", "Subtotal", Cart.format(subtotal_cents))
    lines << format("%-36s %9s", "Coupon #{@coupon.code}", "-#{Cart.format(discount_cents)}") if @coupon
    lines << format("%-36s %9s", "Tax", Cart.format(tax_cents))
    lines << format("%-36s %9s", "Total", Cart.format(total_cents))
    lines.join("\n")
  end

  def self.format(cents)
    sign = cents.negative? ? "-" : ""
    dollars, rest = cents.abs.divmod(100)
    "#{sign}$#{dollars}.#{rest.to_s.rjust(2, '0')}"
  end
end
