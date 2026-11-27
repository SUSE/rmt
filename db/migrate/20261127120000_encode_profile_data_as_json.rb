class EncodeProfileDataAsJson < ActiveRecord::Migration[8.1]
  # Before Profile serialized data as JSON, the TEXT column held the Ruby
  # #to_s of the client value. Arrays of strings are already valid JSON.
  # Re-encode every other value as a JSON string, so that reads keep
  # returning exactly what was stored before.
  def up
    safety_assured do
      execute 'UPDATE profiles SET data = JSON_QUOTE(data) WHERE JSON_VALID(data) = 0'
    end
  end
end
