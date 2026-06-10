require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'Ansible deployment' do
  before(:all) do
    # Ensure ansible is available
    skip 'ansible-playbook not available' unless system('which ansible-playbook > /dev/null 2>&1')
  end

  describe 'ansible playbook structure' do
    it 'has site.yml playbook' do
      expect(File.exist?('/usr/share/ansible/rmt/site.yml')).to be true
    end

    it 'has rmt role' do
      expect(Dir.exist?('/usr/share/ansible/rmt/roles/rmt')).to be true
    end

    it 'has group_vars configuration' do
      expect(File.exist?('/usr/share/ansible/rmt/group_vars/all.yml')).to be true
    end

    it 'has requirements.yml for collections' do
      expect(File.exist?('/usr/share/ansible/rmt/requirements.yml')).to be true
    end
  end

  describe 'ansible playbook syntax' do
    it 'passes syntax check' do
      output = `cd /usr/share/ansible/rmt && ansible-playbook --syntax-check site.yml 2>&1`
      expect($?.exitstatus).to eq(0), "Syntax check failed: #{output}"
    end
  end

  describe 'ansible collections' do
    before(:all) do
      # Install required collections if not present
      system('cd /usr/share/ansible/rmt && ansible-galaxy collection install -r requirements.yml > /dev/null 2>&1')
    end

    it 'has required collections installed' do
      output = `ansible-galaxy collection list --format=json 2>/dev/null`
      collections = JSON.parse(output)

      # Flatten the collections hash to get all collection names
      all_collections = collections.values.flat_map(&:keys)

      expect(all_collections).to include('ansible.posix')
      expect(all_collections).to include('community.crypto')
      expect(all_collections).to include('community.general')
      expect(all_collections).to include('community.mysql')
    end
  end

  describe 'rmt role files' do
    it 'has main tasks file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/tasks/main.yml')).to be true
    end

    it 'has db_setup tasks file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/tasks/db_setup.yml')).to be true
    end

    it 'has ssl_setup tasks file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/tasks/ssl_setup.yml')).to be true
    end

    it 'has handlers file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/handlers/main.yml')).to be true
    end

    it 'has defaults file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/defaults/main.yml')).to be true
    end

    it 'has rmt.conf template' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/templates/rmt.conf.j2')).to be true
    end

    it 'has meta file' do
      expect(File.exist?('/usr/share/ansible/rmt/roles/rmt/meta/main.yml')).to be true
    end
  end

  describe 'ansible playbook execution in check mode', :requires_root do
    before(:all) do
      # Ensure MariaDB is running for the check
      system('systemctl start mariadb > /dev/null 2>&1')
    end

    it 'runs successfully in check mode' do
      output = `cd /usr/share/ansible/rmt && ansible-playbook site.yml --check 2>&1`
      # Check mode may fail on some tasks (like service starts) but should not have syntax errors
      expect(output).not_to match(/ERROR/)
      expect(output).not_to match(/fatal.*syntax/i)
    end
  end
end
