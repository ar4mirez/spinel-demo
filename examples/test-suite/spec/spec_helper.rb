# frozen_string_literal: true

require_relative "../lib/cart"

FIXTURES = File.expand_path("../fixtures", __dir__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end

# `catalog` in every group that includes it: fixtures/catalog.yml, loaded
# fresh for each example by `let`.
RSpec.shared_context "catalog fixture" do
  let(:catalog) { Cart::Catalog.load(File.join(FIXTURES, "catalog.yml")) }
end
