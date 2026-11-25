# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Cart::Catalog do
  include_context "catalog fixture"

  it "loads every product in the fixture" do
    expect(catalog.products.keys).to contain_exactly("BOOK-RUBY", "MUG", "STICKERS")
  end

  it "reads a product's attributes, taxable by default" do
    expect(catalog.product("MUG")).to have_attributes(name: "Spinel mug", price_cents: 1250, taxable: true)
    expect(catalog.product("BOOK-RUBY").taxable).to be(false)
  end

  it "looks coupons up case-insensitively" do
    expect(catalog.coupon("welcome10").percent_off).to eq(10)
  end

  it "raises for an unknown coupon" do
    expect { catalog.coupon("FREE") }.to raise_error(Cart::InvalidCoupon)
  end

  context "with a stubbed catalog file" do
    it "builds products from whatever YAML it is given" do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with("stub.yml").and_return(<<~YAML)
        products:
          PEN: { name: Pen, price_cents: 150, taxable: false }
      YAML
      stubbed = described_class.load("stub.yml")
      expect(stubbed.product("PEN").price_cents).to eq(150)
      expect(stubbed.coupons).to be_empty
    end
  end
end
