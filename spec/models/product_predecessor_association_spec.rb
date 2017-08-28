require 'rails_helper'

RSpec.describe ProductPredecessorAssociation, type: :model do

  it { is_expected.to validate_presence_of(:product_id) }
  it { is_expected.to validate_presence_of(:predecessor_id) }

end
