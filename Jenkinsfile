pipeline {
    agent { 
        node {label 'bare-metal' }
    } 
    stages {
        stage('Build') { 
            steps {
                // Build container
                sh 'echo Build shock server'
                sh 'docker build -t shock:testing .' 
                sh 'echo Build test client'
                sh 'docker build -t shock-test-client:testing -f test/Dockerfile .'
            }
        }
        stage('Setup') {
            steps {
                // Create network
                sh '''
                    UP=`docker network ls | grep shock-test` 
                    if [ -n "$UP" ] ; then  
                        echo Network already up
                    else
                        echo Creatting shock-test network
                        docker network create shock-test
                    fi
                    '''
                // start services
                sh '''
                    if [ -n "`docker ps | grep shock-server-mongodb`" ] ; then
                        echo Still up shock-server-mongodb, reusing
                    else     
                        docker run -d --rm --network shock-test --name shock-server-mongodb --expose=27017 mongo mongod --dbpath /data/db
                    fi
                    '''   
                sh '''
                    if [ -n "`docker ps | grep shock-auth-db" ] ; then
                        echo Still up shock-server-mongodb
                    else    
                        docker run -d --rm --network shock-test \
                                    --env MYSQL_ROOT_PASSWORD=secret \
                                    --env MYSQL_DATABASE=TestAppUsers \
                                    --env MYSQL_USER=authService \
                                    --env MYSQL_PASSWORD=authServicePassword \
                                    -v `pwd`/test/dbsetup.mysql:/tmp/dbsetup.mysql \
                                    --name shock-auth-db mysql:5.7 \
                                    --explicit_defaults_for_timestamp --init-file /tmp/dbsetup.mysql
                    fi
                    '''
                sh '''
                    if [ -n "`docker ps | grep shock-auth-server`" ] ; then
                        echo Still up shock-server-mongodb
                    else    
                        docker run -d --rm --network shock-test --name shock-auth-server \
                        --env MYSQL_HOST=shock-auth-db \
                        --env MYSQL_DATABASE=TestAppUsers \
                        --env MYSQL_USER=authService \
                        --env MYSQL_PASSWORD=authServicePassword \
                        --env PERL5LIB=/usr/local/apache2/cgi-bin \
                        mgrast/authserver:latest
                    fi
                    '''       
                sh '''
                    UP=`docker ps | grep "shock-server$"`
                    if [ -n "$UP" ] ; then
                        echo Found old shock server, stopping and starting new one
                        docker stop shock-server
                    fi     
                    docker run -d --rm --network shock-test --name shock-server --expose=7445 shock:testing /go/bin/shock-server --hosts shock-server-mongodb --oauth_urls "http://shock-auth-server/cgi-bin/?action=data" --oauth_bearers oauth --write 0
                    '''        
            }
        }
        stage('Test') { 
            steps {
                // execute tests
                sh 'docker run -t --rm --network shock-test shock-test-client:testing  /shock-tester.sh -h http://shock-server -p 7445'
                sh '''docker run -t --rm --network shock-test --env SHOCK_HOST="http://shock-server" --env SHOCK_PORT=7445 shock-test-client:testing \
                    pytest /go/src/github.com/MG-RAST/Shock/test/test_shock.py'''
            }   
        }
    }
    post {
        always {
             // shutdown container and network
                sh '''
                    docker stop shock-server shock-server-mongodb
                    docker rmi shock:testing shock-test-client:testing
                    docker network rm shock-test
                    // delete images
                    '''
        }
    }
}
