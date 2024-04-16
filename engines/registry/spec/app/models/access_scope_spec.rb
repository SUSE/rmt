require 'yaml'
require 'spec_helper'

RSpec.describe AccessScope, type: :model do
  subject { build(:registry_access_scope) }

  describe '.name' do
    context 'without repository' do
      subject(:build_call) { build(:registry_access_scope, namespace: nil, image: 'leap') }

      it 'returns the repo' do
        expect(build_call.name).to eq('leap')
      end
    end

    context 'normal <namespace>/<image>' do
      subject(:build_call) { build(:registry_access_scope, namespace: 'suse', image: 'leap') }

      it 'returns the repo' do
        expect(build_call.name).to eq('suse/leap')
      end
    end

    context 'nested <namespace>/<namespace2>/<image>' do
      subject(:build_call) { build(:registry_access_scope, namespace: 'suse/test', image: 'leap') }

      it 'returns the repo' do
        expect(build_call.name).to eq('suse/test/leap')
      end
    end
  end

  describe '#parse' do
    context 'without namespace' do
      subject(:parse) { described_class.parse('repository:leap:pull') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('repository:leap:pull')
      end
    end

    context 'normal <namespace>/<image>' do
      subject(:parse) { described_class.parse('repository:suse/leap:pull') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('repository:suse/leap:pull')
      end
    end

    context 'nested <namespace>/<namespace>/<image>' do
      subject(:parse) { described_class.parse('repository:suse/leap/leap:pull') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('repository:suse/leap/leap:pull')
      end
    end

    context 'with multiple actions' do
      subject(:parse) { described_class.parse('repository:suse/leap/leap:pull,push') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('repository:suse/leap/leap:pull,push')
      end
    end

    context 'with class' do
      subject(:parse) { described_class.parse('repository(class):suse/leap/leap:pull,push') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('repository(class):suse/leap/leap:pull,push')
      end
    end

    context 'with different type' do
      subject(:parse) { described_class.parse('registry:catalog:*') }

      it 'returns the scope' do
        expect(parse.to_s).to eq('registry:catalog:*')
      end
    end

    context 'with valid string' do
      it 'allows dots in scope' do
        scope = 'repository:rancher/elemental/elemental-teal-channel/5.3:pull'
        expect(described_class.parse(scope).to_s).to eq(scope)
      end
    end

    context 'with invalid string' do
      it 'raises on empty scope' do
        expect { described_class.parse('') }.to raise_error(Registry::Exceptions::InvalidScope, /Empty scope/)
      end

      it 'raises on nil scope' do
        expect { described_class.parse(nil) }.to raise_error(Registry::Exceptions::InvalidScope, /Empty scope/)
      end

      it 'raises on more than 2 ":"' do
        expect { described_class.parse('repo:test:tag:pull') }.to raise_error(Registry::Exceptions::InvalidScope, /Invalid scope format/)
      end

      it 'raises on invalid characters' do
        expect { described_class.parse('repo$:test:pull') }.to raise_error(Registry::Exceptions::InvalidScope, /Invalid scope format/)
      end
    end
  end

  describe ".granted['actions']" do
    let(:product1) do
      product = FactoryBot.create(:product, :with_mirrored_repositories)
      product.repositories.where(enabled: false).update(mirroring_enabled: false)
      product
    end
    let(:product2) do
      product = FactoryBot.create(:product, :with_mirrored_repositories)
      product.repositories.where(enabled: false).update(mirroring_enabled: false)
      product
    end
    let(:system) do
      system = FactoryBot.create(:system)
      system.activations << [
        FactoryBot.create(:activation, system: system, service: product1.service),
        FactoryBot.create(:activation, system: system, service: product2.service)
      ]
      system
    end
    let(:client) do
      double( # rubocop:disable RSpec/VerifiedDoubles
        :registryclient,
        account: 'foo',
          systems: [system]
        )
    end

    context 'when namespace is null' do
      subject(:access_scope) { described_class.new(type: 'a', name: 'b', actions: 'c') }
      # let(:scope) { build(:registry_access_scope, namespace: 'suse', image: 'leap') }

      it 'returns default auth actions' do
        possible_access = access_scope.granted(client: client)

        expect(possible_access).to eq({ 'type' => 'a', 'actions' => ['pull'], 'class' => nil, 'name' => 'b' })
      end
    end

    context 'when namespace is not null' do
      let(:access_policy_content) { File.read('engines/registry/spec/data/access_policy_yaml.yml') }

      context 'when action is allowed' do
        subject(:access_scope) do
          described_class.new(
            type: 'a',
            name: 'suse/sles/*',
            actions: ['pull']
            )
        end

        it 'returns default auth actions (no free repos included)' do
          yaml_string = access_policy_content
          data = YAML.safe_load yaml_string
          data[product1.product_class] = 'suse/**'
          File.write('engines/registry/spec/data/access_policy_yaml.yml', YAML.dump(data))
          allow_any_instance_of(RegistryCatalogService).to receive(:repos).and_return(['suse/sles/super_repo'])
          allow(File).to receive(:read).and_return(access_policy_content)
          possible_access = access_scope.granted(client: client)

          expect(possible_access).to eq(
            {
              'type' => 'a',
              'actions' => ['pull'],
              'class' => nil,
              'name' => 'suse/sles/*'
            }
            )
        end
      end

      context 'when action is not allowed' do
        subject(:access_scope) do
          described_class.new(
            type: 'a',
            name: 'suse/sles/*',
            actions: ['push']
            )
        end

        it 'returns empty auth actions' do
          allow_any_instance_of(RegistryCatalogService).to receive(:repos).and_return(['suse/sles/super_repo'])
          allow(File).to receive(:read).and_return(access_policy_content)
          possible_access = access_scope.granted(client: client)

          expect(possible_access).to eq(
            {
              'type' => 'a',
              'actions' => [],
              'class' => nil,
              'name' => 'suse/sles/*'
            }
            )
        end
      end

      context 'when repo name is not allowed' do
        subject(:access_scope) do
          described_class.new(
            type: 'a',
            name: 'super_expensive/suse/sles/*',
            actions: ['pull']
            )
        end

        it 'returns empty auth actions' do
          allow_any_instance_of(RegistryCatalogService).to receive(:repos).and_return(['suse/sles/super_repo'])
          allow(File).to receive(:read).and_return(access_policy_content)
          possible_access = access_scope.granted(client: client)

          expect(possible_access).to eq(
            {
              'type' => 'a',
              'actions' => [],
              'class' => nil,
              'name' => 'super_expensive/suse/sles/*'
            }
            )
        end
      end
    end
  end
end
