# frozen_string_literal: true

module JsonApi
  # Checks a parsed JSON object against a small schema and returns only the
  # fields the schema knows. `errors` maps each bad field to its messages, the
  # shape the API returns in a 422.
  #
  #   SCHEMA = { "title" => { type: String, required: true, max: 200 } }
  #   v = Validator.new(SCHEMA, body)
  #   v.valid? ? v.attributes : v.errors
  class Validator
    TYPE_NAMES = { String => "a string", Integer => "an integer", Array => "an array" }.freeze
    PLURALS = { String => "strings", Integer => "integers" }.freeze

    attr_reader :errors, :attributes

    # partial: true checks only the fields present (for PATCH).
    def initialize(schema, input, partial: false)
      @errors = {}
      @attributes = {}
      unknown = input.keys - schema.keys
      unknown.each { |key| add(key, "is not allowed") }
      schema.each do |field, rules|
        if input.key?(field)
          check(field, input[field], rules)
        elsif rules[:required] && !partial
          add(field, "is required")
        end
      end
    end

    def valid? = @errors.empty?

    private

    def check(field, value, rules)
      unless value.is_a?(rules[:type])
        return add(field, "must be #{TYPE_NAMES.fetch(rules[:type])}")
      end
      if value.is_a?(String)
        return add(field, "must not be blank") if value.strip.empty?
        add(field, "must be at most #{rules[:max]} characters") if rules[:max] && value.length > rules[:max]
      end
      if value.is_a?(Integer) && rules[:range] && !rules[:range].cover?(value)
        add(field, "must be between #{rules[:range].min} and #{rules[:range].max}")
      end
      if value.is_a?(Array) && rules[:of] && !value.all? { |item| item.is_a?(rules[:of]) }
        add(field, "must contain only #{PLURALS.fetch(rules[:of])}")
      end
      @attributes[field] = value if @errors[field].nil?
    end

    def add(field, message) = (@errors[field] ||= []) << message
  end
end
