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
          create :product, :with_mirrored_repositories, :cloned, :activated,
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
      let!(:sle12sp1) do
        create :product, :with_mirrored_repositories, :cloned,
          from: sle12, name: 'sle12sp1', version: '12.1', predecessors: [sle12]
      end
      let!(:sle12sp2) do
        create :product, :with_mirrored_repositories, :cloned, from: sle12,
          name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
      end

      context 'multiple base migration targets' do
        let(:installed_products) { [sle12] }

        it { is_expected.to contain_exactly([sle12sp1], [sle12sp2]) }
      end

      context 'one base migration target' do
        let!(:sle12sp1) do
          create :product, :with_mirrored_repositories, :cloned, :activated,
            from: sle12, system: system, name: 'sle12sp1', version: '12.1', predecessors: [sle12]
        end
        let(:installed_products) { [sle12sp1] }

        it { is_expected.to contain_exactly([sle12sp2]) }
      end

      context 'no migration target' do
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned, :activated,
            from: sle12, system: system, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
        end
        let(:installed_products) { [sle12sp2] }

        it { is_expected.to be_empty }
      end
    end

    context 'with base plus extension products' do
      let!(:sle12sp1) do
        create :product, :with_mirrored_repositories, :cloned,
          from: sle12, name: 'sle12sp1', version: '12.1', predecessors: [sle12]
      end
      let(:sdk12) do
        create :product, :with_mirrored_repositories, :activated, system: system, base_products: [sle12], name: 'sdk12',
          product_type: 'extension', free: true
      end
      let!(:sdk12sp1) do
        create :product, :with_mirrored_repositories, :cloned,
          from: sdk12, name: 'sdk12sp1', base_products: [sle12sp1], predecessors: [sdk12], product_type: 'extension'
      end
      let(:sleha12) do
        create(
          :product, :with_mirrored_repositories, :activated,
          system: system, base_products: [sle12], name: 'sleha12', product_type: 'extension'
        )
      end
      let!(:sleha12sp1) do
        create :product, :with_mirrored_repositories, :cloned,
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
          create :product, :with_mirrored_repositories, :cloned,
            from: slehageo12, name: 'slehageo12sp1', base_products: [sleha12sp1], predecessors: [slehageo12], root_product: sle12sp1
        end
        let!(:slehageosub) { create(:subscription, product_classes: [slehageo12.product_class]) }

        let(:installed_products) { [sle12, sleha12, slehageo12] }

        it { is_expected.to contain_exactly([sle12sp1, sleha12sp1, slehageo12sp1]) }
      end

      context 'available modules do not get added automatically to the migration target' do
        let!(:sle15) do
          create :product, :with_mirrored_repositories,
            :cloned, from: sle12sp1,
            name: 'sle15', version: '15', predecessors: [sle12sp1]
        end
        let!(:sle15_module) do
          create :product, :module, :with_mirrored_repositories,
            name: 'sle15module', version: '15', base_products: [sle15]
        end
        let(:system) { create :system }
        let(:installed_products) { [sle12sp1] }

        before do
          system.activations.create(service: sle12sp1.service)
        end

        it { is_expected.to contain_exactly([sle15]) }
      end

      context 'when the successor product is a base' do
        # For example, a system with (SLES 12 SP x) + (LTSS 12 SP x) could upgrade to (SLES 12 SP x+1)
        let(:ltss12) do
          create :product, :extension, :with_mirrored_repositories, :activated, system: system,
            name: 'ltss12', base_products: [sle12]
        end
        let!(:sle12sp1) do
          create :product, :with_mirrored_repositories, :cloned, from: sle12,
            name: 'sle12sp1', predecessors: [sle12, ltss12]
        end
        let(:system) { create :system }
        let(:installed_products) { [sle12, ltss12] }

        it { is_expected.to contain_exactly([sle12sp1]) }
      end

      context 'when the new product has multiple predecessors' do
        # This is the case, for example, of an offline migration from SLE12 to SLE15.
        # A SLE12 system can have HA12 & HA-GEO12 installed, but those extensions
        # were merged into a single HA15 extension. The engine should then simply offer
        # SLE15+HA15 as a possible migration.
        let!(:sle12_extension) { sleha12sp1 }
        let!(:sle12_extension_extension) do
          create :product, :extension, :with_mirrored_repositories, :cloned, from: sle12_extension,
            name: 'sleha-geo12sp1', base_products: [sle12_extension]
        end
        let(:extension_subscription) { create :subscription, product_classes: [sle12_extension.product_class] }
        let!(:sle15) do
          create :product, :with_mirrored_repositories, :cloned, from: sle12sp1,
            name: 'sle15', predecessors: [sle12sp1]
        end
        let!(:sle15_merged_extension) do
          create :product, :extension, :with_mirrored_repositories, :cloned,
          from: sle12_extension, predecessors: [sle12_extension, sle12_extension_extension], base_products: [sle15]
        end
        let(:system) { create :system }
        let(:installed_products) { [sle12sp1, sle12_extension, sle12_extension_extension] }

        before do
          system.activations.create(service: sle12sp1.service)
          system.activations.create(service: sle12_extension.service)
          system.activations.create(service: sle12_extension_extension.service)
        end

        it { is_expected.to contain_exactly([sle15, sle15_merged_extension]) }
      end

      context 'when only the extension can get upgraded' do
        let!(:cloud7) do
          create(:product, :with_mirrored_repositories, :activated, system: system, name: 'Cloud 7', version: '7',
            base_products: [sle12], product_type: 'extension')
        end
        let!(:cloud8) do
          create(:product, :with_mirrored_repositories, :cloned,
            from: cloud7, name: 'Cloud 8', version: '8', predecessors: [cloud7], base_products: [sle12])
        end
        let!(:cloud9) do
          create(:product, :with_mirrored_repositories, :cloned,
            from: cloud7, name: 'Cloud 9', version: '9',
            predecessors: [cloud7, cloud8], base_products: [sle12])
        end

        let(:installed_products) { [sle12, sdk12, cloud7] }

        its(:first) { is_expected.to match_array([sle12, sdk12, cloud9]) }
        its(:second) { is_expected.to match_array([sle12, sdk12, cloud8]) }
      end

      context 'multiple migrations for base plus modules' do
        let!(:sle12sp2) do
          create :product, :with_mirrored_repositories, :cloned,
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
          create :product, :with_mirrored_repositories, :cloned,
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
          create :product, :with_mirrored_repositories, base_products: [sle12sp1], predecessors: [sdk12], name: 'sdk12sp1beta',
            product_type: 'extension', free: true
        end
        let(:installed_products) { [sle12, sdk12] }

        it { is_expected.to contain_exactly([sle12sp1, sdk12sp1], [sle12sp1, sdk12sp1beta]) }
      end

      describe 'sorting' do
        context 'simple case with no dependencies' do
          let!(:sle12sp1) do
            create :product, :with_mirrored_repositories, :cloned, from: sle12,
              name: 'sle12sp1', version: '12.1', predecessors: [sle12]
          end
          let!(:sle12sp2) do
            create :product, :with_mirrored_repositories,
              :cloned, from: sle12, name: 'sle12sp2', version: '12.2', predecessors: [sle12sp1, sle12]
          end
          let!(:docker_module) do
            create :product, :module, :with_mirrored_repositories, :activated, system: system, name: 'docker', base_products: [sle12, sle12sp1, sle12sp2]
          end
          let(:installed_products) { [docker_module, sle12] }

          it 'sorts migration paths by latest version first, and puts the base first in each migration path' do
            is_expected.to eq([[sle12sp2, docker_module], [sle12sp1, docker_module]])
          end
        end
      end

      describe 'offline/online migration filtering' do
        # This is the product relationship tree being tested:
        #
        # A -online-> B -offline-> C -> online D
        #              \
        #           offline
        #                \
        #                 C'

        let(:product_class) { create :product_class }
        let!(:product_a) { create :product, :with_mirrored_repositories }
        let!(:product_b) do
          create :product, :with_mirrored_repositories, predecessors: [product_a],
            migration_kind: :online
        end
        let!(:product_c) do
          create :product, :with_mirrored_repositories, predecessors: [product_b],
            migration_kind: :offline
        end
        let!(:product_c_prime) do
          create :product, :with_mirrored_repositories, predecessors: [product_b],
            migration_kind: :offline
        end

        describe '#online_migrations' do
          subject { engine.online_migrations }

          let(:installed_products) { [product_a] }
          let(:system) { create :system, :with_activated_product, product: product_a }

          it 'does not contain offline migrations' do
            is_expected.to contain_exactly([product_b])
          end

          context 'python2 module gets added to SLE 15 online migrations' do
            let(:installed_products) { [sle15] }
            let(:system) { create :system, :with_activated_product, product: sle15 }

            let!(:sle15) do
              create :product, :with_mirrored_repositories,
                name: 'sle15', version: '15'
            end
            let!(:sle15_sp1) do
              create :product, :with_mirrored_repositories,
                :cloned, from: sle15,
                name: 'sle15-sp1', version: '15.1', predecessors: [sle15]
            end
            let!(:python2_module) do
              create :product, :module, :with_mirrored_repositories,
                identifier: 'sle-module-python2', version: '15.1', base_products: [sle15_sp1],
                arch: sle15.arch
            end

            it 'contains python2 module' do
              is_expected.to contain_exactly([sle15_sp1, python2_module])
            end
          end
        end

        describe '#offline_migrations' do
          subject { engine.offline_migrations(target_base_product) }

          let(:installed_products) { [product_b] }
          let(:target_base_product) { product_c }
          let(:system) { create :system, :with_activated_product, product: product_b }


          it 'gives an offline migratable base product' do
            is_expected.to contain_exactly([product_c])
          end

          context 'with desired base that is not a migration from installed product' do
            let(:target_base_product) { product_a }

            it { is_expected.to be_empty }
          end

          # Example: SLES 15 system gets upgraded to SLES 15 SP1
          # The SLES 15 SP1 recommended modules should not be offered in this case,
          # since recommended modules should only get added when doing a major upgrade (12 to 15)
          context 'when doing an offline upgrade to the next service pack' do
            let!(:product_d) do
              create :product, :with_mirrored_repositories, predecessors: [product_c],
              migration_kind: :online
            end
            let!(:target_product_recommended_module) do
              create(:product, :module, :with_mirrored_repositories).tap do |mod|
                ProductsExtensionsAssociation.create(
                  product: product_d,
                  extension: mod,
                  root_product: product_d,
                  recommended: true
                )
              end
            end
            let(:installed_products) { [product_c] }
            let(:target_base_product) { product_d }
            let(:system) { create :system, :with_activated_product, product: product_c }

            it 'does not include recommended modules' do
              is_expected.to contain_exactly([product_d])
            end
          end

          # Example: SLED 12 system should get upgraded to SLED 15 + recommended modules
          context 'when the new base product has recommended modules' do
            let!(:recommended_module) do
              create(:product, :module, :with_mirrored_repositories).tap do |mod|
                ProductsExtensionsAssociation.create(
                  product: product_c,
                  extension: mod,
                  root_product: product_c,
                  recommended: true
                )
              end
            end

            it { is_expected.to contain_exactly([target_base_product, recommended_module]) }
          end

          # Example: SLED 12 + SDK system should get upgraded to SLED 15 + Dev Tools Module + recommended modules,
          # since Dev Tools Module is the successor of SDK
          context 'when the new base product has recommended modules, and the old base has a module with a successor' do
            let!(:recommended_module) do
              create(:product, :module, :with_mirrored_repositories).tap do |mod|
                ProductsExtensionsAssociation.create(
                  product: target_base_product,
                  extension: mod,
                  root_product: target_base_product,
                  recommended: true
                )
              end
            end

            let!(:additional_module) do
              create(:product, :module, :with_mirrored_repositories, base_products: [product_b]).tap do |mod|
                system.activations << create(:activation, system: system, service: mod.service)
              end
            end

            let!(:additional_module_successor) do
              # Note that the successor of the additional module sits on top of the recommended module (Dev Tools case)
              create(:product, :module, :with_mirrored_repositories, predecessors: [additional_module], migration_kind: :offline,
                base_products: [recommended_module], root_product: target_base_product)
            end

            let(:installed_products) { [product_b, additional_module] }

            it 'does not drop other non-recommended successors' do
              is_expected.to contain_exactly([target_base_product, recommended_module, additional_module_successor])
            end
          end


          context "modules with a 'migration_extra' flag are added automatically to the migration target and sorted" do
            before do
              # stub method to test that the migration is being sorted
              original_modules_for_migration = Product.method(:modules_for_migration)

              allow(Product).to receive(:modules_for_migration).with(anything) do |target_base_product_id|
                original_modules_for_migration.call(target_base_product_id).reverse
              end
            end

            let!(:target_product_extra_module) do
              create(:product, :module, :with_mirrored_repositories).tap do |mod|
                ProductsExtensionsAssociation.create(
                  product: product_c,
                  extension: mod,
                  root_product: product_c,
                  migration_extra: true
                )
              end
            end
            let!(:target_product_extra_module_child) do
              create(:product, :module, :with_mirrored_repositories, predecessors: [product_c], migration_kind: :offline).tap do |mod|
                ProductsExtensionsAssociation.create(
                  product: product_c,
                  extension: mod,
                  root_product: product_c,
                  migration_extra: true
                )
              end
            end

            it { is_expected.to contain_exactly([product_c, target_product_extra_module, target_product_extra_module_child]) }
          end

          context 'python2 module gets added to SLE 15 offline migrations' do
            let(:installed_products) { [sle15] }
            let(:target_base_product) { sle15_sp1 }
            let(:system) { create :system, :with_activated_product, product: sle15 }

            let!(:sle15) do
              create :product, :with_mirrored_repositories,
                name: 'sle15', version: '15'
            end
            let!(:sle15_sp1) do
              create :product, :with_mirrored_repositories,
                :cloned, from: sle15,
                name: 'sle15-sp1', version: '15.1', predecessors: [sle15]
            end
            let!(:python2_module) do
              create :product, :module, :with_mirrored_repositories,
                identifier: 'sle-module-python2', version: '15.1', base_products: [sle15_sp1],
                arch: sle15.arch
            end

            it 'contains python2 module' do
              is_expected.to contain_exactly([sle15_sp1, python2_module])
            end
          end
        end
      end
    end
  end

  describe '#sort_migrations' do
    let(:installed_products) { [sle12] }
    let(:system) { FactoryGirl.create(:system, :with_activated_base_product) }

    it 'removes duplicate migration paths' do
      expect(engine.send(:sort_migrations, [[sle12], [sle12], [sle12]])).to eq([[sle12]])
    end
  end
end
