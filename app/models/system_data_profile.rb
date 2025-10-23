class SystemDataProfile < ApplicationRecord
  # relationships

  # we should only ever be triggering destroy as a result of
  # a cascaded destroy from removing a system, and we should
  # not be deleting the entries if there are still references
  has_many :system_profiles # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :systems, through: :system_profiles

  # validations
  validates :profile_type, presence: true
  validates :profile_id, presence: true
  validates :profile_data, presence: true

  def self.where_unique_keys(key_tuples)
    # generate an expanded where clause with one entry per key_tuple
    # and pass the flattened list of key tuples as arguments
    where_clause = key_tuples.map { '(profile_type = ? AND profile_id = ?)' }.join(' OR ')
    where_args = key_tuples.flatten
    where(where_clause, *where_args)
  end
end
