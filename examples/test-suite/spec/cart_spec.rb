# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Cart do
  include_context "catalog fixture"

  subject(:cart) { described_class.new(catalog, tax_rate_percent: 8) }

  it "starts empty" do
    expect(cart).to be_empty
    expect(cart.total_cents).to eq(0)
  end

  describe "#add" do
    it "counts quantities per product" do
      cart.add("MUG").add("MUG", 2).add("STICKERS")
      expect(cart.quantity("MUG")).to eq(3)
      expect(cart.item_count).to eq(4)
    end

    it "rejects products the catalog does not have" do
      expect { cart.add("NOPE") }.to raise_error(Cart::UnknownProduct, /unknown product: NOPE/)
    end

    it "rejects quantities below one" do
      expect { cart.add("MUG", -1) }.to raise_error(ArgumentError)
    end
  end

  describe "#remove" do
    before { cart.add("MUG", 3) }

    it "takes away some of a line" do
      expect { cart.remove("MUG", 1) }.to change { cart.quantity("MUG") }.from(3).to(2)
    end

    it "drops the line when no quantity is given" do
      cart.remove("MUG")
      expect(cart).to be_empty
    end
  end

  describe "totals" do
    before { cart.add("BOOK-RUBY").add("MUG", 2) }

    it "taxes only the taxable lines" do
      expect(cart).to have_attributes(subtotal_cents: 6499, tax_cents: 200, total_cents: 6699)
    end
  end

  describe "#apply_coupon" do
    context "when the subtotal is high enough" do
      before { cart.add("MUG", 2) }

      it "discounts before tax" do
        cart.apply_coupon("welcome10")
        expect(cart.coupon.code).to eq("WELCOME10")
        expect([cart.discount_cents, cart.tax_cents, cart.total_cents]).to eq([250, 180, 2430])
      end
    end

    context "when the subtotal is below the coupon's minimum" do
      before { cart.add("STICKERS") }

      it "refuses the coupon" do
        expect { cart.apply_coupon("BIG25") }
          .to raise_error(Cart::InvalidCoupon, "BIG25 needs a subtotal of at least $100.00")
        expect(cart.coupon).to be_nil
      end
    end
  end

  describe "#receipt" do
    it "lists each line and the total" do
      cart.add("BOOK-RUBY").add("STICKERS", 2)
      expect(cart.receipt).to include("The Ruby Book").and match(/^Total\s+\$50\.77$/)
    end
  end

  describe ".format" do
    {5 => "$0.05", 1250 => "$12.50", -100 => "-$1.00"}.each do |cents, text|
      it "formats #{cents} cents as #{text}" do
        expect(described_class.format(cents)).to eq(text)
      end
    end
  end
end
