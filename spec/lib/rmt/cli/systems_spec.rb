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

      context 'with --csv --all option' do
        let(:argv) { ['list', '--csv', '--all'] }

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

  describe '#purge' do
    context 'argument error' do
      it 'raises a CLI error when given a wrong date' do
        msg = "The given date does not follow the proper format. Ensure it follows this format '<year>-<month>-<day>'.\n"
        expect { described_class.start(['purge', '--no-confirmation', '--before', 'whatever']) }
          .to raise_error(SystemExit)
                .and output(msg).to_stderr
      end
    end

    context 'no systems to be purged quiet' do
      let(:argv) { ['purge', '-q'] }

      before do
        create :system, :with_activated_product, last_seen_at: 1.month.ago
      end

      it 'shows a warning if there are no systems matching the query' do
        bf = RMT::CLI::Systems::INACTIVE.ago.strftime('%F')
        expect($stdin).to receive(:gets).and_return('y')
        expect { described_class.start(argv) }.to(
          output("Do you want to delete all the matching systems that contacted this RMT before #{bf}? (y/n) ").to_stdout.and \
            output("No systems to be purged on this RMT instance. All systems have contacted RMT after #{bf}.\n").to_stderr
        )
      end
    end

    context 'no systems to be purged' do
      let(:argv) { ['purge'] }

      before do
        create :system, :with_activated_product, last_seen_at: 1.month.ago
      end

      it 'shows a warning if there are no systems matching the query' do
        bf = RMT::CLI::Systems::INACTIVE.ago.strftime('%F')
        expect { described_class.start(argv) }.to(
          output("No systems to be purged on this RMT instance. All systems have contacted RMT after #{bf}.\n").to_stderr
        )
      end
    end

    context 'there are systems to be purged quiet' do
      let!(:s1) { create :system, :with_activated_product, last_seen_at: 2.months.ago }
      let!(:s2) { create :system, :with_activated_product, last_seen_at: 4.months.ago } # rubocop:disable RSpec/LetSetup
      let(:relation_double) { instance_double(ActiveRecord::Relation) }

      it 'removes systems by following the default definition of inactive' do
        expect(System.count).to eq 2

        expect { described_class.start(['purge', '--no-confirmation', '-q']) }
          .to output(
            /1 systems destroyed.Purged all systems that have not contacted this RMT since #{Time.zone.today - 3.months}./m
        ).to_stdout

        expect(System.count).to eq 1
        expect(System.first.id).to eq s1.id
      end

      it 'removes systems by the given date' do
        expect(System.count).to eq 2

        argv = ['purge', '--no-confirmation', '-q', '--before', Time.zone.now.strftime('%F')]
        expect { described_class.start(argv) }
          .to output(/2 systems destroyed.Purged all systems that have not contacted this RMT since #{Time.zone.today}./m).to_stdout

        expect(System.count).to eq 0
      end

      it 'retry to remove systems if there is an error' do
        expect(System.count).to eq 2

        allow(System).to receive(:where).and_return(relation_double)
        allow(relation_double).to receive(:in_batches).and_raise('FOO')
        argv = ['purge', '--no-confirmation', '-q', '--before', Time.zone.now.strftime('%F')]
        expect { described_class.start(argv) }
          .to output(<<~STDOUT).to_stdout
            Error while purging systems: RuntimeError FOO. Retrying in 5 seconds (1/3)
            Error while purging systems: RuntimeError FOO. Retrying in 5 seconds (2/3)
            Could not delete all systems last seen before #{Time.zone.today}: FOO
            Systems that have not contacted this RMT since #{Time.zone.today} may still be in this RMT
          STDOUT

        expect(System.count).to eq 2
      end
    end

    context 'there are systems to be purged' do
      let!(:product_a) { create :product, :with_mirrored_repositories, name: 'product-foo' }
      let!(:product_b) { create :product, :with_mirrored_repositories, name: 'product-bar' }
      let!(:s1) { create :system, :with_activated_product, hostname: 'foo-bars', last_seen_at: 2.months.ago, product: product_a }
      let!(:s2) { create :system, :with_activated_product, hostname: 'Hostname', last_seen_at: 4.months.ago, product: product_b }
      let!(:single_row) do
        if s2.activations.first.product.product_string.length < 23
          <<~TEXT
            +---------+----------+-------------------------+-------------------------+------------------------+
            | Login   | Hostname | Registration time       | Last seen               | Products               |
            +---------+----------+-------------------------+-------------------------+------------------------+
            | #{s2.login} | #{s2.hostname} | #{s2.registered_at} | #{s2.last_seen_at} | #{s2.activations.first.product.product_string} |
            +---------+----------+-------------------------+-------------------------+------------------------+
          TEXT
        elsif s2.activations.first.product.product_string.length == 23
          <<~TEXT
            +---------+----------+-------------------------+-------------------------+-------------------------+
            | Login   | Hostname | Registration time       | Last seen               | Products                |
            +---------+----------+-------------------------+-------------------------+-------------------------+
            | #{s2.login} | #{s2.hostname} | #{s2.registered_at} | #{s2.last_seen_at} | #{s2.activations.first.product.product_string} |
            +---------+----------+-------------------------+-------------------------+-------------------------+
          TEXT
        end
      end
      let!(:multiple_rows) do
        if s2.activations.first.product.product_string.length < 23
          <<~TEXT
            +---------+----------+-------------------------+-------------------------+------------------------+
            | Login   | Hostname | Registration time       | Last seen               | Products               |
            +---------+----------+-------------------------+-------------------------+------------------------+
            | #{s2.login} | #{s2.hostname} | #{s2.registered_at} | #{s2.last_seen_at} | #{s2.activations.first.product.product_string} |
            | #{s1.login} | #{s1.hostname} | #{s1.registered_at} | #{s1.last_seen_at} | #{s1.activations.first.product.product_string} |
            +---------+----------+-------------------------+-------------------------+------------------------+
          TEXT
        elsif s2.activations.first.product.product_string.length == 23
          <<~TEXT
            +---------+----------+-------------------------+-------------------------+-------------------------+
            | Login   | Hostname | Registration time       | Last seen               | Products                |
            +---------+----------+-------------------------+-------------------------+-------------------------+
            | #{s2.login} | #{s2.hostname} | #{s2.registered_at} | #{s2.last_seen_at} | #{s2.activations.first.product.product_string} |
            | #{s1.login} | #{s1.hostname} | #{s1.registered_at} | #{s1.last_seen_at} | #{s1.activations.first.product.product_string} |
            +---------+----------+-------------------------+-------------------------+-------------------------+
          TEXT
        end
      end
      let(:query_relation_double) { instance_double(ActiveRecord::Relation) }
      let(:mock_batch)    { instance_double(ActiveRecord::Batches::BatchEnumerator) }

      it 'removes systems by following the default definition of inactive' do
        expect(System.count).to eq 2

        stub_const('RMT::CLI::Systems::DELETE_BATCH_SIZE', 1)

        expect { described_class.start(['purge', '--no-confirmation']) }
           .to output(<<~TEXT).to_stdout
             1 systems last seen before #{Time.zone.today - 3.months}
             #{single_row}Purged all systems that have not contacted this RMT since #{Time.zone.today - 3.months}.
           TEXT

        expect(System.count).to eq 1
        expect(System.first.id).to eq s1.id
      end

      it 'removes systems by the given date' do
        expect(System.count).to eq 2

        stub_const('RMT::CLI::Systems::DELETE_BATCH_SIZE', 1)
        argv = ['purge', '--no-confirmation', '--before', Time.zone.now.strftime('%F')]
        expect { described_class.start(argv) }
          .to output(<<~TEXT).to_stdout
            1 systems last seen before #{Time.zone.today}
            2 systems last seen before #{Time.zone.today}
            #{multiple_rows}1 systems to be deleted
            Purged all systems that have not contacted this RMT since #{Time.zone.today}.
          TEXT
        expect(System.count).to eq 0
      end

      it 'handle a DB error' do
        expect(System.count).to eq 2

        allow(System).to receive(:where).and_return(query_relation_double)
        allow(query_relation_double).to receive(:in_batches).and_raise('FOO')
        argv = ['purge', '--no-confirmation', '--before', Time.zone.now.strftime('%F')]
        expect { described_class.start(argv) }
          .to output(<<~TEXT).to_stdout
            Could not get all systems last seen before #{Time.zone.today}: RuntimeError FOO
          TEXT

        expect(System.count).to eq 2
      end

      it 'retry to remove systems if there is an error' do
        expect(System.count).to eq 2

        allow(System).to receive(:where) do |*args|
          if args.first.is_a?(Hash) && args.first.key?(:id)
            query_relation_double
          else
            System.method(:where).super_method.call(*args)
          end
        end
        allow(query_relation_double).to receive(:destroy_all).and_raise('BAR')
        argv = ['purge', '--no-confirmation', '--before', Time.zone.now.strftime('%F')]
        expect { described_class.start(argv) }
          .to output(<<~TEXT).to_stdout
            2 systems last seen before #{Time.zone.today}
            #{multiple_rows}Error while purging systems: RuntimeError BAR. Attempt 1/3, retrying in 5 seconds
            Error while purging systems: RuntimeError BAR. Attempt 2/3, retrying in 5 seconds
            Error while purging the systems: RuntimeError BAR, all 2 systems could not be removed, 2 systems still in the database
          TEXT

        expect(System.count).to eq 2
      end
    end

    context 'purge confirmations' do
      let!(:s1) { create :system, :with_activated_product, last_seen_at: 2.months.ago }
      let!(:s2) { create :system, :with_activated_product, last_seen_at: 4.months.ago } # rubocop:disable RSpec/LetSetup
      let(:confirmation) { "Do you want to delete all the matching systems that contacted this RMT before #{Time.zone.today - 3.months}? (y/n) " }
      let(:purge) { "Purged all systems that have not contacted this RMT since #{Time.zone.today - 3.months}." }

      it 'asks for confirmation' do
        expect(System.count).to eq 2
        expect($stdin).to receive(:gets).and_return('y')

        expect { described_class.start(['purge', '-q']) }
          .to output(<<~TEXT).to_stdout
            #{confirmation}1 systems destroyed
            Purged all systems that have not contacted this RMT since #{Time.zone.today - 3.months}.
          TEXT

        expect(System.count).to eq 1
        expect(System.first.id).to eq s1.id
      end

      it 'doesn\'t purge when answer is no' do
        expect(System.count).to eq 2
        expect($stdin).to receive(:gets).and_return('n')

        expect { described_class.start(['purge', '-q']) }
          .to output("Do you want to delete all the matching systems that contacted this RMT before #{Time.zone.today - 3.months}? (y/n) ").to_stdout

        expect(System.count).to eq 2
      end

      it 'loops when answer is invalid' do
        expect(System.count).to eq 2
        expect($stdin).to receive(:gets).and_return('e')
        expect($stdin).to receive(:gets).and_return('n')

        expect { described_class.start(['purge', '-q']) }
          .to output(/Please answer/).to_stderr.and \
            output(
              "Do you want to delete all the matching systems that contacted this RMT before #{Time.zone.today - 3.months}? (y/n) " \
                "Do you want to delete all the matching systems that contacted this RMT before #{Time.zone.today - 3.months}? (y/n) "
            ).to_stdout

        expect(System.count).to eq 2
      end
    end
  end
end
