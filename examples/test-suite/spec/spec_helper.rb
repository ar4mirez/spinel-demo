# frozen_string_literal: true

require_relative "../lib/cart"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end

# `catalog` in every group that includes it: fixtures/catalog.yml, loaded
# fresh for each example by `let`.
RSpec.shared_context "catalog fixture" do
  fixtures = File.expand_path("../fixtures", __dir__)

  let(:catalog) { Cart::Catalog.load(File.join(fixtures, "catalog.yml")) }
end
