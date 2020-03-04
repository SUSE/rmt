require 'rails_helper'

RSpec.describe RMT::CLI::Products do
  describe 'list-command' do
    subject(:command) { described_class.start(argv) }

    let(:argv) { ['list'] }

    it 'mentions --all option' do
      expect { described_class.start(argv) }.to output(
        "Only enabled products are shown by default. Use the '--all' option to see all products.\n"
      ).to_stdout.and output(/No matching products found/).to_stderr
    end

    context 'with empty database' do
      context 'with no options' do
        it 'warns about no matches' do
          expect { described_class.start(argv) }.to output(
            "No matching products found in the database.\n"
          ).to_stderr.and output(/Only enabled products are shown/).to_stdout
        end
      end

      context 'with --all option' do
        let(:argv) { ['list', '--all'] }

        it 'warns about running sync command first' do
          expect { described_class.start(argv) }.to output(
            "Run 'rmt-cli sync' to synchronize with your SUSE Customer Center data first.\n"
          ).to_stderr
        end

        it 'does not mention --all option' do
          expect { described_class.start(argv) }.to output('').to_stdout.and output(/rmt-cli sync/).to_stderr
        end
      end
    end

    context 'with products in database' do
      let!(:disabled_product) { create :product } # rubocop:disable RSpec/LetSetup
      let!(:enabled_product) { create :product, :with_mirrored_repositories }
      let!(:beta_product) { create :product, release_stage: 'beta' }

      let(:expected_output) do
        Terminal::Table.new(
          headings: ['ID', 'Product', 'Version', 'Arch', 'Mirror?', 'Last mirrored'],
          rows: expected_rows
        ).to_s + "\n" + "Only enabled products are shown by default. Use the '--all' option to see all products.\n"
      end

      context 'with no options' do
        let(:expected_rows) do
          [[
            enabled_product.id,
            "#{enabled_product.name}\n#{enabled_product.product_string}",
            enabled_product.version,
            enabled_product.arch,
            enabled_product.mirror? ? 'Mirror' : "Don't Mirror",
            enabled_product.last_mirrored_at
          ]]
        end

        it 'lists only enabled products' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end

      context 'with --csv option' do
        let(:argv) { ['list', '--csv'] }
        let(:expected_rows) do
          [[
            enabled_product.id,
            enabled_product.name,
            enabled_product.version,
            enabled_product.arch,
            enabled_product.product_string,
            enabled_product.release_stage,
            enabled_product.mirror?,
            enabled_product.last_mirrored_at
          ]]
        end
        let(:expected_output) do
          CSV.generate { |csv| expected_rows.each { |row| csv << row } }
        end

        it 'lists all products' do
          expect { described_class.start(argv) }.to output(/#{expected_output}/).to_stdout.and output('').to_stderr
        end

        it 'does not mention --all option' do
          expect { described_class.start(argv) }.not_to output(/--all/).to_stdout
        end
      end

      context 'with --all option' do
        let(:argv) { ['list', '--all'] }
        let(:expected_output) do
          Terminal::Table.new(
            headings: ['ID', 'Product', 'Version', 'Arch', 'Mirror?', 'Last mirrored'],
            rows: expected_rows
          ).to_s + "\n"
        end
        let(:expected_rows) do
          Product.all.map do |product|
            [
              product.id,
              "#{product.name}\n#{product.product_string}",
              product.version,
              product.arch,
              product.mirror? ? 'Mirror' : "Don't Mirror",
              product.last_mirrored_at
            ]
          end
        end

        it 'lists all products' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end

      context 'with --release-stage option' do
        let(:expected_output) do
          Terminal::Table.new(
            headings: ['ID', 'Product', 'Version', 'Arch', 'Mirror?', 'Last mirrored'],
            rows: expected_rows
          ).to_s + "\n"
        end
        let(:argv) { ['list', '--all', '--release-stage', 'beta'] }
        let(:expected_rows) do
          [[
            beta_product.id,
            "#{beta_product.name}\n#{beta_product.product_string}",
            beta_product.version,
            beta_product.arch,
            beta_product.mirror? ? 'Mirror' : "Don't Mirror",
            beta_product.last_mirrored_at
          ]]
        end

        it 'lists only products in that release stage' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        end
      end
    end
  end

  describe '#enable' do
    let(:product) { create :product, :with_not_mirrored_repositories }
    let(:repos) { product.repositories.where(enabled: true) }
    let(:extensions) { [] }
    let(:target) { '' }
    let(:products_to_enable) { [product] + extensions }
    let(:argv) { ['enable', target] }
    let(:expected_output) do
      output = "Found product by target #{target}: #{product.friendly_name}.\n"
      output += "Enabling #{product.friendly_name}:\n"
      products_to_enable.each do |p|
        output += "  #{p.friendly_name}:\n"
        p.repositories.where(enabled: true).pluck(:name).sort.each do |repo_name|
          output += "    Enabled repository #{repo_name}.\n"
        end
      end
      output
    end

    context 'with repositories already enabled' do
      let(:target) { product.id.to_s }
      let(:product) { create :product, :with_mirrored_repositories }
      let(:expected_output) do
        output = "Found product by target #{target}: #{product.friendly_name}.\n"
        output += "Enabling #{product.friendly_name}:\n"
        output += "  #{product.friendly_name}:\n"
        output += "    All repositories have already been enabled.\n"
        output
      end

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(true) if repository.enabled
        end
      end
    end

    context 'with multiple ids' do
      let(:product_1) { create :product, :with_not_mirrored_repositories }
      let(:product_2) { create :product, :with_not_mirrored_repositories }
      let(:product_3) { create :product, :with_not_mirrored_repositories }
      let(:products_to_enable) { [product_1, product_2, product_3] }
      let(:repos) { products_to_enable.flat_map { |product| product.repositories.where(enabled: true) } }
      let(:expected_output) do
        output = ''
        products_to_enable.each do |product|
          output += "Found product by target #{product.id}: #{product.friendly_name}.\n"
          output += "Enabling #{product.friendly_name}:\n"
          output += "  #{product.friendly_name}:\n"
          product.repositories.where(enabled: true).pluck(:name).sort.each do |repo_name|
            output += "    Enabled repository #{repo_name}.\n"
          end
        end
        output
      end

      context 'with multi-input' do
        let(:argv) { ['enable', product_1.id, product_2.id, product_3.id] }

        it 'enables product repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end
      end

      context 'with commas' do
        let(:argv) { ['enable', "#{product_1.id}, #{product_2.id}, #{product_3.id}"] }

        it 'enables product repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end
      end

      context 'with mixed spaces and commas' do
        let(:argv) { ['enable', "#{product_1.id}, #{product_2.id} #{product_3.id}"] }

        it 'enables product repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end
      end

      context 'with spaces' do
        let(:argv) { ['enable', "#{product_1.id} #{product_2.id} #{product_3.id}"] }

        it 'enables product repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end
      end
    end

    context 'by product ID' do
      let(:target) { product.id.to_s }

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(repository.enabled)
        end
      end

      context 'with recommended extensions' do
        let(:product) { create :product, :with_not_mirrored_repositories }
        let(:extensions) do
          [
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true)
          ]
        end
        let(:repos) { products_to_enable.flat_map { |product| product.repositories.where(enabled: true) } }
        let(:products_to_enable) { [product] + extensions }

        it 'enables product and recommended products repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end

        it 'has more repositories than the base product' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          expect(repos.count).to be > product.repositories.where(enabled: true).count
        end
      end

      context 'with option --all-modules' do
        let(:argv) { ['enable', target, '--all-modules'] }
        let(:product) { create :product, :with_not_mirrored_repositories }
        let(:extensions) do
          [
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: true, product_type: :module),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: true, product_type: :module),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: true, product_type: :extension)
          ]
        end
        let!(:non_free_extensions) do
          [
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: false, product_type: :module),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: false, product_type: :module),
            create(:product, :extension, :with_not_mirrored_repositories, base_products: [product], recommended: false, free: false, product_type: :extension)
          ]
        end
        let(:all_products) { [product] + extensions + non_free_extensions }
        let(:products_to_enable) { all_products - non_free_extensions }
        let(:repos) { products_to_enable.flat_map { |product| product.repositories.where(enabled: true) } }

        it 'enables product and recommended products repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          products_to_enable.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to eq(repository.enabled)
          end
        end

        it 'does not enable non-free extensions' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          non_free_extensions.flat_map(&:repositories).each do |repository|
            expect(repository.mirroring_enabled).to be_falsey
          end
        end

        it 'has more repositories than the base product' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          expect(repos.count).to be > product.repositories.where(enabled: true).count
        end
      end
    end

    context 'by wrong product string' do
      let(:target) { 'badproductstring' }
      let(:argv) { ['enable', target] }
      let(:expected_stderr) { "Product #{target} could not be found and was not enabled.\n" }
      let(:expected_output) { "No product found for target #{target}.\n" }

      before { allow(described_class).to receive(:exit) }

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_stderr).to_stderr.and output(expected_output).to_stdout
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end
    end

    context 'by wrong product ID' do
      let(:target) { (product.id + 1).to_s }
      let(:argv) { ['enable', target] }
      let(:expected_stderr) { "Product #{target} could not be found and was not enabled.\n" }
      let(:expected_output) { "Product by ID #{target} not found.\n" }

      before { allow(described_class).to receive(:exit) }

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_stderr).to_stderr.and output(expected_output).to_stdout
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end
    end

    context 'by product string' do
      let(:target) { product.product_string }

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(repository.enabled)
        end
      end
    end
  end

  describe '#disable' do
    let(:product) { create :product, :with_mirrored_repositories }
    let(:repos) { product.repositories }
    let(:target) { '' }
    let(:argv) { ['disable', target] }
    let(:expected_output) do
      output = "Found product by target #{target}: #{product.friendly_name}.\n"
      output += "Disabling #{product.friendly_name}:\n"
      output += "  #{product.friendly_name}:\n"
      repos.pluck(:name).sort.each { |repo| output += "    Disabled repository #{repo}.\n" } unless repos.empty?
      output
    end

    context 'already enabled repositories' do
      let(:target) { product.id.to_s }
      let(:product) { create :product, :with_not_mirrored_repositories }

      let(:expected_output) do
        output = "Found product by target #{target}: #{product.friendly_name}.\n"
        output += "Disabling #{product.friendly_name}:\n"
        output += "  #{product.friendly_name}:\n"
        output += "    All repositories have already been disabled.\n"
        output
      end

      it 'enables the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end
    end

    context 'by product ID' do
      let(:target) { product.id.to_s }

      it 'disabled the mandatory product repositories' do
        expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end

      context 'with recommended extensions' do
        let(:product) { create :product, :with_mirrored_repositories }
        let(:extensions) do
          [
            create(:product, :extension, :with_mirrored_repositories, base_products: [product], recommended: true),
            create(:product, :extension, :with_mirrored_repositories, base_products: [product], recommended: true)
          ]
        end

        it 'does not disable extension repositories' do
          expect { described_class.start(argv) }.to output(expected_output).to_stdout.and output('').to_stderr
          product.repositories.each do |repository|
            expect(repository.mirroring_enabled).to eq(false)
          end
          extensions.each do |extension|
            extension.repositories.each do |repository|
              expect(repository.mirroring_enabled).to eq(true)
            end
          end
        end
      end
    end

    context 'failure' do
      let(:expected_stderr) { "Product #{target} could not be found and was not disabled.\n" }
      let(:expected_output) { "No product found for target '#{target}'.\n" }
      let(:argv) { ['disable', target] }

      before { allow(described_class).to receive(:exit) }

      context 'by wrong product ID' do
        let(:expected_output) { "Product by ID #{target} not found.\n" }
        let(:target) { (product.id + 1).to_s }

        it 'leaves the product repositories enabled' do
          expect { described_class.start(argv) }.to output(expected_stderr).to_stderr.and output(expected_output).to_stdout
          product.repositories.each do |repository|
            expect(repository.mirroring_enabled).to eq(true)
          end
        end
      end

      context 'by wrong product string' do
        let(:expected_output) { "No product found for target #{target}.\n" }
        let(:target) { product.product_string + 'foo' }

        it 'leaves the product repositories enabled' do
          expect { described_class.start(argv) }.to output(expected_stderr).to_stderr.and output(expected_output).to_stdout
          product.repositories.each do |repository|
            expect(repository.mirroring_enabled).to eq(true)
          end
        end
      end
    end
  end

  describe '#show' do
    let(:product) { create :product, :with_disabled_not_mirrored_repositories }
    let(:repos) { product.repositories }
    let(:target) { product.id.to_s }
    let(:argv) { ['show', target] }
    let(:expected_output) do
      output = "Product: #{product.friendly_name} (id: #{target})\n"
      output += "Description: #{product.description}\n"
      output += "Repositories:\n"
      repos.each do |repo|
        mandatory = repo.enabled ? 'mandatory' : 'non-mandatory'
        enabled = repo.mirroring_enabled ? 'enabled' : 'not enabled'
        mirrored = repo.last_mirrored_at.present? ? "last mirrored at #{repo.last_mirrored_at.strftime('%Y-%m-%d %H:%M:%S %Z')}" : 'not mirrored'
        output += "* #{repo.name} (id: #{repo.scc_id}) (#{mandatory}, #{enabled}, #{mirrored})\n"
      end
      output
    end

    describe 'success' do
      context 'with disabled and not mirrored repos' do
        it 'shows details of a product and its repos' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end

      context 'with disabled and mirrored repos' do
        let(:product) { create :product, :with_disabled_mirrored_repositories }

        it 'shows details of a product and its repos' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end

      context 'with enabled and not mirrored repos' do
        let(:product) { create :product, :with_not_mirrored_repositories }

        it 'shows details of a product and its repos' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end

      context 'with enabled and mirrored repositories' do
        let(:product) { create :product, :with_mirrored_repositories }

        it 'shows details of a product and its repos' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end

      context 'without the repos' do
        let(:product) { create :product }
        let(:expected_output) do
          output = "Product: #{product.friendly_name} (id: #{target})\n"
          output += "Description: #{product.description}\n"
          output += "Repositories are not available for this product.\n"
          output
        end

        it 'shows details of a product and its repos' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
            .and output('').to_stderr
        end
      end
    end

    describe 'failure' do
      context 'with wrong ID string' do
        let(:target) { '1234' }
        let(:expected_output) { "Product by ID #{target} not found.\n" }

        it 'raises a ProductNotFoundException' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
        end
      end

      context 'with wrong product string' do
        let(:target) { product.product_string + 'foo' }
        let(:expected_output) { "No product found for target #{target}.\n" }

        it 'raises an ProductNotFoundException' do
          expect { described_class.start(argv) }
            .to output(expected_output).to_stdout
        end
      end
    end
  end
end
