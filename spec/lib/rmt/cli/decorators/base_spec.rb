require 'rails_helper'

describe RMT::CLI::Decorators::Base do
  subject(:decorator) { described_class.new }

  describe '#to_csv' do
    it 'raises not implemented error' do
      expect { decorator.to_csv }.to raise_error(NotImplementedError)
    end
  end

  describe '#to_table' do
    it 'raises not implemented error' do
      expect { decorator.to_table }.to raise_error(NotImplementedError)
    end
  end
end
