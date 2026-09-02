require 'rails_helper'
require 'securerandom'

# rubocop:disable Metrics/ModuleLength
module RegistrationSharing
  RSpec.describe RmtToRmtController, type: :request do
    # an exception escaping the controller's System.transaction marks the
    # surrounding transaction for rollback, which breaks the wrapper transaction
    # RSpec puts around each example, so this file cleans up after itself
    self.use_transactional_tests = false

    after do
      Activation.delete_all
      System.delete_all
      Service.delete_all
      Product.delete_all
      DeregisteredSystem.delete_all
    end

    let(:login_payg) { SecureRandom.hex }
    let(:login_byos) { SecureRandom.hex }
    let(:password) { SecureRandom.hex }
    let(:created_at) { Time.zone.now.round - 60 }
    let(:registered_at) { created_at + 5 }
    let(:last_seen_at) { created_at + 5 }
    let(:product) { FactoryBot.create(:product, :with_service) }
    let(:api_secret) { 's3cr3tt0k3n' }
    let(:request_token) { api_secret }
    let(:instance_data) { '<document>test</document>' }
    let(:pubcloud_reg_code) { 'INTERNAL-FOO' }

    before do
      expect(RegistrationSharing).not_to receive(:save_for_sharing)
      allow(Settings).to receive(:[]).with(:regsharing).and_return({ api_secret: api_secret })
    end

    describe '#create byos' do
      before do
        allow(System).to receive(:find_or_create_by).with(
          login: login_byos, password: password, system_token: nil
        ).and_call_original

        post(
          '/api/regsharing',
          params: {
            login: login_byos,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :byos,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with incorrect credentials' do
        let(:request_token) { 'wr0ngt0k3n' }

        it 'returns an error' do
          expect(response).to have_http_status(401)
        end
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_byos) }

          it { is_expected.not_to eq(nil) }
          its(:password) { is_expected.to eq(password) }
          its(:created_at) { is_expected.to eq(created_at) }
          its(:registered_at) { is_expected.to eq(registered_at) }
          its(:last_seen_at) { is_expected.to eq(last_seen_at) }
          its(:proxy_byos_mode) { is_expected.to eq('byos') }
          its(:pubcloud_reg_code) { is_expected.to eq('INTERNAL-FOO') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end

        context 'activation' do
          subject(:activation) { System.find_by(login: login_byos).activations.first }

          it { is_expected.not_to eq(nil) }
          it 'has correct product_id' do
            expect(activation.product.id).to eq(product.id)
          end
          its(:created_at) { is_expected.to eq(created_at) }
        end
      end
    end

    describe '#create payg' do
      before do
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :payg,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('payg') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe '#create hybrid' do
      before do
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :hybrid,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('hybrid') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe 'duplicate race condition' do
      before do
        System.create!(
          login: login_payg,
          password: password,
          system_token: login_payg
        )
        allow(System).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordNotUnique)
        allow(System).to receive(:find_by!).and_call_original
        post(
          '/api/regsharing',
          params: {
            login: login_payg,
            password: password,
            system_token: login_payg,
            created_at: created_at,
            registered_at: registered_at,
            last_seen_at: last_seen_at,
            proxy_byos_mode: :hybrid,
            pubcloud_reg_code: pubcloud_reg_code,
            activations: [
              {
                product_id: product.id,
                created_at: created_at
              }
            ],
            instance_data: instance_data
          },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        it 'falls back to find_by!' do
          expect(System).to have_received(:find_by!)
        end

        it 'does not retry a uniqueness violation' do
          expect(System).to have_received(:find_or_create_by).once
        end

        context 'system' do
          subject(:system) { System.find_by(login: login_payg) }

          it { is_expected.not_to eq(nil) }
          its(:proxy_byos_mode) { is_expected.to eq('hybrid') }
          it 'saves instance data' do
            expect(system.instance_data).to eq(instance_data)
          end
        end
      end
    end

    describe 'contention retry' do
      let(:params) do
        {
          login: login_payg,
          password: password,
          created_at: created_at,
          registered_at: registered_at,
          last_seen_at: last_seen_at,
          proxy_byos_mode: :payg,
          activations: [{ product_id: product.id, created_at: created_at }],
          instance_data: instance_data
        }
      end

      # the backoff has nothing to wait for in a test
      before { stub_const("#{described_class}::DEADLOCK_BACKOFF", 0) }

      def post_regsharing
        post('/api/regsharing', params: params, headers: { 'Authorization' => "Bearer #{request_token}" })
      end

      # raises on the first 'failures' calls to target.method, then behaves normally
      def fail_first(target, method, error, failures)
        calls = 0
        allow(target).to receive(method).and_wrap_original do |original, *args, **kwargs, &block|
          calls += 1
          raise error if calls <= failures

          original.call(*args, **kwargs, &block)
        end
      end

      {
        'a deadlock' => ActiveRecord::Deadlocked,
        'a lock wait timeout' => ActiveRecord::LockWaitTimeout
      }.each do |description, error_class|
        context "when #{description} clears on the second attempt" do
          before do
            allow(Rails.logger).to receive(:warn).and_call_original
            fail_first(System, :find_or_create_by, error_class.new('contention'), 1)
            post_regsharing
          end

          it 'performs HTTP request successfully' do
            expect(response).to have_http_status(204)
          end

          it 'retried exactly once' do
            expect(System).to have_received(:find_or_create_by).twice
          end

          it 'creates exactly one system' do
            expect(System.where(login: login_payg).count).to eq(1)
          end

          it 'creates the activation' do
            expect(System.find_by(login: login_payg).activations.count).to eq(1)
          end

          it 'logs the retry' do
            expect(Rails.logger).to(
              have_received(:warn).with(
                %r{#{Regexp.escape(error_class.name)}.*attempt 1/#{described_class::DEADLOCK_RETRIES}}
              )
            )
          end
        end
      end

      context 'when contention hits after the system row is created' do
        before do
          fail_first(Product, :includes, ActiveRecord::Deadlocked.new('contention'), 1)
          post_regsharing
        end

        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        it 'rolls the first attempt back rather than duplicating the system' do
          expect(System.where(login: login_payg).count).to eq(1)
        end

        it 'creates the activation exactly once' do
          expect(System.find_by(login: login_payg).activations.count).to eq(1)
        end
      end

      context 'when the contention does not clear' do
        before do
          fail_first(
            System, :find_or_create_by,
            ActiveRecord::Deadlocked.new('contention'),
            described_class::DEADLOCK_RETRIES
          )
        end

        it 'lets the error through' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
        end

        it 'stops after DEADLOCK_RETRIES attempts' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
          expect(System).to have_received(:find_or_create_by).exactly(described_class::DEADLOCK_RETRIES).times
        end

        it 'does not persist the system' do
          expect { post_regsharing }.to raise_error(ActiveRecord::Deadlocked)
          expect(System.find_by(login: login_payg)).to eq(nil)
        end
      end

      context 'when the error is not contention' do
        before { fail_first(System, :find_or_create_by, ActiveRecord::RecordNotFound.new('missing'), 1) }

        it 'does not retry' do
          expect { post_regsharing }.to raise_error(ActiveRecord::RecordNotFound)
          expect(System).to have_received(:find_or_create_by).once
        end
      end
    end

    describe '#destroy' do
      let!(:system) { FactoryBot.create(:system) }

      before do
        delete(
          '/api/regsharing',
          params: { login: system.login },
          headers: { 'Authorization' => "Bearer #{request_token}" }
        )
      end

      context 'with incorrect credentials' do
        let(:request_token) { 'wr0ngt0k3n' }

        it 'returns an error' do
          expect(response).to have_http_status(401)
        end
      end

      context 'with correct credentials' do
        it 'performs HTTP request successfully' do
          expect(response).to have_http_status(204)
        end

        it 'removes the system' do
          expect { System.find(system.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
