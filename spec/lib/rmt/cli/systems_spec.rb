require 'rails_helper'
require_relative '../../../../engines/registration_sharing/lib/registration_sharing'

RSpec.describe RMT::CLI::Systems do
  describe '#list' do
    subject(:command) { described_class.start(argv) }

    context 'with systems in database' do
      let(:system1) { create :system, :with_activated_product, hostname: 'host1', last_seen_at: Time.now.utc - 3 }
      let(:system2) { create :system, :with_activated_product, hostname: 'host2', last_seen_at: Time.now.utc - 2 }
      let(:system3) { create :system, :with_activated_product, hostname: 'host3', last_seen_at: Time.now.utc - 1 }
      let(:headings) { [ 'Login', 'Hostname', 'Registration time', 'Last seen', 'Products' ] }
      let(:expected_rows) do
        expected_systems.map do |system|
          [
            system.login,
            system.hostname,
            system.registered_at,
            system.last_seen_at,
            system.products.map { |p| p.identifier.downcase + '/' + p.version + '/' + p.arch }.join("\n")
          ]
        end
      end

      before do
        system1
        system2
        system3
      end

      context 'with --limit option' do
        let(:argv) { ['list', '-l', '2'] }

        let(:expected_systems) do
          System.where(
            id: [
              system3.id,
              system2.id
            ]
          ).order(id: :desc)
        end

        let(:expected_output) do
          Terminal::Table.new(
            headings: headings,
            rows: expected_rows
          ).to_s + "\n" + "Showing last 2 registrations. Use the '--all' option to see all registered systems.\n"
        end

        it 'lists last 2 registered systems' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end

      context 'with --all option' do
        let(:argv) { ['list', '--all'] }

        let(:expected_systems) do
          System.where(
            id: [
              system3.id,
              system2.id,
              system1.id
            ]
          ).order(id: :desc)
        end

        let(:expected_output) do
          Terminal::Table.new(
            headings: headings,
            rows: expected_rows
          ).to_s + "\n"
        end

        it 'lists all registered systems' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end

      context 'with --csv option' do
        let(:argv) { ['list', '--csv'] }
        let(:expected_systems) do
          System.where(
            id: [
              system3.id,
              system2.id,
              system1.id
            ]
          ).order(id: :desc)
        end
        let(:expected_output) do
          CSV.generate { |csv| ([headings] + expected_rows).each { |row| csv << row } }
        end

        it 'produces CSV optput' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end

      context 'system with associated subscription' do
        let(:subscription) { create :subscription, :with_products }
        let(:product) { subscription.products.first }
        let(:system3) { create :system, :with_activated_product, product: product, subscription: subscription }

        let(:argv) { ['list'] }

        it 'shows the regcode associated' do
          expect { described_class.start(argv) }.to output(/\(Regcode: #{subscription.regcode}\)/).to_stdout
        end
      end
    end

    context 'without registrations in the DB' do
      let(:argv) { ['list'] }

      it 'outputs a warning' do
        expect { described_class.start(argv) }.to output('').to_stdout.and \
          output("There are no systems registered to this RMT instance.\n").to_stderr
      end
    end
  end

  describe '#scc-sync' do
    subject(:command) { described_class.start(['scc-sync']) }

    it 'runs sync_systems' do
      expect_any_instance_of(RMT::SCC).to receive(:sync_systems)
      command
    end
  end

  describe '#remove' do
    describe 'success' do
      let(:system) { create :system, :with_activated_product, hostname: 'host1', last_seen_at: Time.now.utc - 3, scc_system_id: '123123' }
      let(:argv) { ['remove', system.login] }
      let(:expected_output) { "Successfully removed system with login #{system.login}.\n" }

      it 'removes the system with all its products, repositories, activations and services' do
        expect { described_class.start(argv) }
          .to output(expected_output).to_stdout
          .and output('').to_stderr
          .and change { System.count }.from(1).to(0)
          .and change { system.products.count }.from(1).to(0)
          .and change { system.activations.count }.from(1).to(0)
          .and change { system.repositories.count }.from(4).to(0)
          .and change { system.services.count }.from(1).to(0)
          .and change { DeregisteredSystem.count }.by(1)
      end

      context 'when regsharing is set' do
        it 'de registration is shared with peers' do
          expect(RegistrationSharing).to receive(:save_for_sharing).at_least(:once)

          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end
    end

    describe 'failure' do
      context 'with wrong target string' do
        let(:argv) { ['remove', '1'] }
        let(:expected_output) { "System with login 1 not found.\n" }

        it 'raises ActiveRecord::RecordNotFound' do
          expect { described_class.start(argv) }
            .to raise_error(SystemExit)
            .and output(expected_output).to_stderr
        end
      end

      context 'when the record can\'t be destroyed' do
        let(:argv) { ['remove', system.login] }
        let(:expected_output) { "System with login #{system.login} cannot be removed.\n" }
        let(:system) { create :system, :with_activated_product }

        it 'raises ActiveRecord::RecordNotDestroyed' do
          expect_any_instance_of(System).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
          expect { described_class.start(argv) }
            .to raise_error(SystemExit)
            .and output(expected_output).to_stderr
        end
      end
    end
  end
end
