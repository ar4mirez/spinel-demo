# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/cart"

FIXTURES = File.expand_path("../fixtures", __dir__)

# The fixture catalog from fixtures/catalog.yml, parsed once per process and
# shared by every test that includes this module.
module Fixtures
  def self.catalog
    @catalog ||= Cart::Catalog.load(File.join(FIXTURES, "catalog.yml"))
  end

  def catalog = Fixtures.catalog
end
