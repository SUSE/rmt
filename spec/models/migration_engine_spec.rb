require 'spec_helper'
require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
# rubocop:disable RSpec/LetSetup

describe MigrationEngine do
  # Using product_with_mirrored_repositories because it initializes service, needed for activations
  let(:sle12) { create :product, :with_mirrored_repositories, version: '12', name: 'sle12' }
  let(:pc_test) { FFaker.bothify('PRODUCT-###-BETA') }
  let(:engine) { described_class.new(system, installed_products) }

  describe '#generate' do
    subject(:migrations) { engine.generate }

    let(:sle12sub) { create(:subscription, product_classes: [sle12.product_class]) }
    let(:system) { FactoryGirl.create(:system, :with_activated_base_product) }
    let!(:activation) { create :activation, system: system, service: sle12.service }

    context 'error handling' do
      context 'multiple base products' do
        let!(:sle12sp1) do
          create :product, :with_mirrored_repositories, :cloned, :activated, :with_predecessors,
            system: system, from: sle12, name: 'sle12sp1',
            version: '12.1', predecessors: [sle12]
        end
        let(:installed_products) { [sle12, sle12sp1] }

        it 'raises' do
          expect { migrations }.to raise_error(RuntimeError, /Multiple base products found/)
        end
      end

      context 'no base product' do
        let(:sdk12) do
          create :product, :with_mirrored_repositories, :activated, system: system, base_products: [sle12], name: 'sdk12',
            product_type: 'extension', product_class: sle12.product_class
        end
        let(:installed_products) { [sdk12] }

        it 'raises' do
          expect { migrations }.to raise_error(RuntimeError, /No base product found/)
        end
      end

      context 'requested migration product not activated' do
        let!(:cloud7) { create(:product, :with_mirrored_repositories, name: 'Cloud 7', version: '7', base_products: [sle12], product_type: 'extension') }
        let(:installed_products) { [sle12, cloud7] }

        it 'raises' do
          expect { migrations }.to raise_error do |error|
            expect(error).to be_a(MigrationEngine::MigrationEngineError)
            expect(error.data).to eq(cloud7.friendly_name)
          end
        end
      end
    end

    context 'with no upgradeable products' do
      let!(:slepos) { create(:product, :with_mirrored_repositories, name: 'SLEPOS') }
      let!(:slepossub) { create(:subscription, product_classes: [slepos.product_class]) }
      let!(:system) { FactoryGirl.create(:system, :with_activated_base_product) }
      let!(:activation) { create :activation, system: system, service: slepos.service }
      let(:installed_products) { [slepos] }

      it { is_expected.to be_empty }
    end

    context 'with upgradeable base product' do
      let!(:sle12sp1) { create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
                          from: sle12, name: 'sle12sp1', version: '12.1', predecessors: [sle12] }
      let!(:sle12sp2) do
        create :product, :with_mirrored_repositories, :cloned, :with_predecessors, from: sle12,
          name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
      end

      context 'multiple base migration targets' do
        let(:installed_products) { [sle12] }

        it { is_expected.to contain_exactly([sle12sp1], [sle12sp2]) }
      end

      context 'one base migration target' do
        let!(:sle12sp1) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors, :activated,
            from: sle12, system: system, name: 'sle12sp1', version: '12.1', predecessors: [sle12]
        end
        let(:installed_products) { [sle12sp1] }

        it { is_expected.to contain_exactly([sle12sp2]) }
      end

      context 'no migration target' do
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors, :activated,
            from: sle12, system: system, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
        end
        let(:installed_products) { [sle12sp2] }

        it { is_expected.to be_empty }
      end
    end

    context 'with base plus extension products' do
      let!(:sle12sp1) { create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
        from: sle12, name: 'sle12sp1', version: '12.1', predecessors: [sle12] }
      let(:sdk12) do
        create :product, :with_mirrored_repositories, :activated, system: system, base_products: [sle12], name: 'sdk12',
          product_type: 'extension', free: true
      end
      let!(:sdk12sp1) do
        create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
          from: sdk12, name: 'sdk12sp1', base_products: [sle12sp1], predecessors: [sdk12], product_type: 'extension'
      end
      let(:sleha12) do
        create(
          :product, :with_mirrored_repositories, :activated,
          system: system, base_products: [sle12], name: 'sleha12', product_type: 'extension'
        )
      end
      let!(:sleha12sp1) do
        create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
          from: sleha12, name: 'sleha12sp1', base_products: [sle12sp1], predecessors: [sleha12], product_type: 'extension'
      end

      context 'with simple dependencies' do
        let(:installed_products) { [sle12, sleha12, sdk12] }

        its(:first) { is_expected.to match_array([sle12sp1, sleha12sp1, sdk12sp1]) }
      end

      context 'with complex dependencies (sles->ha->ha-geo)' do
        let!(:slehageo12) do
          create :product, :with_mirrored_repositories, :activated, system: system, name: 'slehageo12', base_products: [sleha12],
            product_type: 'extension'
        end
        let!(:slehageo12sp1) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
            from: slehageo12, name: 'slehageo12sp1', base_products: [sleha12sp1], predecessors: [slehageo12], root_product: sle12sp1
        end
        let!(:slehageosub) { create(:subscription, product_classes: [slehageo12.product_class]) }

        let(:installed_products) { [sle12, sleha12, slehageo12] }

        it { is_expected.to contain_exactly([sle12sp1, sleha12sp1, slehageo12sp1]) }
      end

      context 'when only the extension can get upgraded' do
        let!(:cloud7) do
          create(:product, :with_mirrored_repositories, :activated, system: system, name: 'Cloud 7', version: '7',
            base_products: [sle12], product_type: 'extension')
        end
        let!(:cloud8) do
          create(:product, :with_mirrored_repositories, :cloned, :with_predecessors,
            from: cloud7, name: 'Cloud 8', version: '8', predecessors: [cloud7], base_products: [sle12])
        end
        let!(:cloud9) do
          create(:product, :with_mirrored_repositories, :cloned, :with_predecessors,
            from: cloud7, name: 'Cloud 9', version: '9',
            predecessors: [cloud7, cloud8], base_products: [sle12])
        end

        let(:installed_products) { [sle12, sdk12, cloud7] }

        its(:first) { is_expected.to match_array([sle12, sdk12, cloud9]) }
        its(:second) { is_expected.to match_array([sle12, sdk12, cloud8]) }
      end

      context 'multiple migrations for base plus modules' do
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
          from: sle12, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
        end
        let!(:docker_module) do
          create(
            :product, :with_mirrored_repositories, :activated,
            system: system, name: 'docker', base_products: [sle12, sle12sp1, sle12sp2], product_type: 'extension'
          )
        end
        let!(:machinery_module) do
          create :product, :with_mirrored_repositories, :activated, system: system, name: 'machinery',
            base_products: [sle12, sle12sp1, sle12sp2], product_type: 'extension'
        end
        let(:installed_products) { [sle12, docker_module, machinery_module] }

        it { is_expected.to contain_exactly([sle12sp1, docker_module, machinery_module], [sle12sp2, docker_module, machinery_module]) }
      end

      context 'when not all products are upgradeable but still compatible' do
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
          from: sle12, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
        end
        let!(:docker_module) do
          create(
            :product, :with_mirrored_repositories, :activated,
            system: system, name: 'docker', base_products: [sle12, sle12sp1, sle12sp2], product_type: 'extension'
          )
        end
        let(:installed_products) { [sle12, docker_module, sdk12] }

        it { is_expected.to contain_exactly([sle12sp1, docker_module, sdk12sp1]) }
      end

      context 'when not all products are upgradeable' do
        let(:slewe12) do
          create(
            :product, :with_mirrored_repositories, :activated,
            system: system, base_products: [sle12], name: 'slewe12', product_type: 'extension'
          )
        end
        let(:installed_products) { [sle12, slewe12] }

        it { is_expected.to be_empty }
      end

      context 'with base plus free extension of beta class' do
        let!(:sdk12sp1beta) do
          create :product, :with_mirrored_repositories, :with_predecessors, base_products: [sle12sp1], predecessors: [sdk12], name: 'sdk12sp1beta',
            product_type: 'extension', free: true
        end
        let(:installed_products) { [sle12, sdk12] }

        it { is_expected.to contain_exactly([sle12sp1, sdk12sp1], [sle12sp1, sdk12sp1beta]) }
      end

      context 'sorts base product first' do
        let!(:sle12sp1) { create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
          from: sle12, name: 'sle12sp1', version: '12.1', predecessors: [sle12] }
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned, :with_predecessors,
            from: sle12, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
        end
        let!(:docker_module) do
          create(
            :product, :with_mirrored_repositories, :activated,
            system: system, name: 'docker', base_products: [sle12, sle12sp1, sle12sp2], product_type: 'extension'
          )
        end
        let(:installed_products) { [docker_module, sle12] }

        context 'given extension product first' do
          it { is_expected.to contain_exactly([sle12sp1, docker_module], [sle12sp2, docker_module]) }
        end

        context 'migration targets have latest base version first' do
          it { is_expected.to eq([[sle12sp2, docker_module], [sle12sp1, docker_module]]) }
        end
      end
    end
  end
end
