node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/potato.git', branch: 'master'
    }

    stage('docker-compose build') {
        dir('potato') {
            sh 'docker-compose build'
        }
    }

    stage('run tests') {
        dir('potato') {
            sh 'docker-compose run potato bash -c "bundler.ruby2.4 && rails db:migrate && rspec"'
        }
    }
}
