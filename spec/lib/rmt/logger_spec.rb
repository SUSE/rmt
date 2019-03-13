require 'rails_helper'

RSpec.describe RMT::Logger do
  describe 'logging format' do
    subject(:logger) { described_class.new(log) }

    let(:log) { StringIO.new }

    context 'with env variable' do
      before do
        ENV['LOG_TO_JOURNALD'] = '1'
      end

      it do
        logger.info('42')
        log.rewind
        expect(log.read).to eq("<6>INFO: RMT version #{RMT::VERSION}\n<6>INFO: 42\n")
      end
    end

    context 'without env variable' do
      before do
        ENV['LOG_TO_JOURNALD'] = nil
      end

      it do
        Timecop.freeze(Time.local(2018, 4, 4, 11, 11, 0)) do # rubocop:disable Rails/TimeZone
          logger.info('42')
          log.rewind
          expect(log.read).to eq("I, [2018-04-04T11:11:00.000000 ##{Process.pid}]  INFO -- : 42\n")
        end
      end
    end
  end
end
