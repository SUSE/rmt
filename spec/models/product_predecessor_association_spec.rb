require 'rails_helper'

RSpec.describe ProductPredecessorAssociation, type: :model do
  describe 'associations' do
    it { is_expected.to validate_presence_of(:product_id) }
    it { is_expected.to validate_presence_of(:predecessor_id) }
  end

  describe 'attributes' do
    it { is_expected.to define_enum_for(:kind).with_values(%i[online offline]) }
  end
end
