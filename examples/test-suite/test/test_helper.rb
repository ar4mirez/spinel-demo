# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/cart"

# The fixture catalog from fixtures/catalog.yml, parsed once per process and
# shared by every test that includes this module.
module Fixtures
  DIR = File.expand_path("../fixtures", __dir__)

  def self.catalog
    @catalog ||= Cart::Catalog.load(File.join(DIR, "catalog.yml"))
  end

  def catalog = Fixtures.catalog
end
