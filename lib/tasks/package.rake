namespace :package do
  package_dir = 'package/'
  package_name = 'rmt-server'
  obs_project = 'systemsmanagement:SCC:RMT'
  local_spec_file = "#{package_name}.spec"
  root_path = File.join(File.dirname(__FILE__), '../..')

  desc 'Checkout from OBS'
  task :checkout do
    Dir.chdir "#{root_path}/#{package_dir}" do
      unless Dir['.osc'].any?
        sh 'mkdir .tmp; mv * .tmp/'
        sh "osc co #{obs_project} #{package_name} -o ."
        puts 'Checkout successful.' if $CHILD_STATUS.exitstatus.zero?
      end
    end
  end
end
