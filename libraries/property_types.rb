# frozen_string_literal: true

# Property helper types shared by the resources. They live in a library rather
# than in the `_base` partial so the helper modules can build them too.

# An Array that compares as a set. Podman returns many lists in an arbitrary
# order, so element order must not look like drift.
class UnorderedArray < Array
  def ==(other)
    other.is_a?(Array) && all? { |value| other.include?(value) }
  end
end

# A Hash that only compares the keys it holds. Podman reports extra entries
# (inherited labels, defaults) that the recipe did not ask for.
class PartialHash < Hash
  def ==(other)
    other.is_a?(Hash) && all? { |key, value| other.key?(key) && other[key] == value }
  end
end

UnorderedArrayType = Chef::Resource.property_type(
  is: [UnorderedArray, nil],
  coerce: proc { |value| value.nil? ? nil : UnorderedArray.new(Array(value)) }
) unless defined?(UnorderedArrayType)

PartialHashType = Chef::Resource.property_type(
  is: [PartialHash, Hash, nil],
  coerce: proc { |value| value.nil? ? nil : PartialHash.new.merge(value) }
) unless defined?(PartialHashType)
