class profile::app::puppet_tomcat::linux (
  String $plsample_version,
  String $tomcat_version,
  String $catalina_dir,
  Array  $tomcat_other_versions,
  Boolean $deploy_sample_app = true,
  String $port,
  String $user,
  $password,
) {

  include ::profile::app::entropy

  class {'::profile::app::java':
    distribution => 'jre',
  }

  class { '::tomcat':
    catalina_home => $catalina_dir,
    before        => Class['java'],
  }

  firewall { '100 allow tomcat access':
    dport  => [8080,8081,8082,8083,8084,8085],
    proto  => tcp,
    action => accept,
  }

  if $deploy_sample_app == true {

    tomcat::instance{ "tomcat${tomcat_version}":
      install_from_source    => true,
      source_url             => "http://${::puppet_server}:81/tomcat/apache-tomcat-${tomcat_version}.tar.gz",
      source_strip_first_dir => true,
      catalina_base          => $catalina_dir,
      catalina_home          => $catalina_dir,
      before                 => Tomcat::War["plsample-${plsample_version}.war"],
    }
    

#    tomcat::config::server { "tomcat${tomcat_version}":
#    port          => $port,
#    }
    tomcat::config::server::tomcat_users { "manager-gui":
      element               => 'role',
      element_name          => 'manager-gui',
    }
    
    tomcat::config::server::tomcat_users { "tomcat${tomcat_version}":
      element_name          => $user,
      password              => $password,
      roles                 => ['manager-gui'],
      notify => Tomcat::Service["plsample-tomcat${tomcat_version}"],
    }
    
    tomcat::config::server::connector { "tomcat${tomcat_version}":
      port                  => $port,
      protocol              => 'HTTP/1.1',
      additional_attributes => {
       'redirectPort' => '8443'
      },
      purge_connectors      => true,
      notify => Tomcat::Service["plsample-tomcat${tomcat_version}"],
    }
    
    tomcat::war { "plsample-${plsample_version}.war" :
      war_source    => "http://${::puppet_server}:81/tomcat/plsample-${plsample_version}.war",
      catalina_base => $catalina_dir,
      notify        => File["${catalina_dir}/webapps/plsample"],
    }

    file { "${catalina_dir}/webapps/plsample":
      ensure => 'link',
      target => "${catalina_dir}/webapps/plsample-${plsample_version}",
      notify => Tomcat::Service["plsample-tomcat${tomcat_version}"],
    }

    tomcat::service { "plsample-tomcat${tomcat_version}":
      catalina_base => $catalina_dir,
      catalina_home => $catalina_dir,
      service_name  => 'plsample',
      subscribe     => Tomcat::War["plsample-${plsample_version}.war"],
    }

  } else {

    tomcat::instance{ "tomcat${tomcat_version}":
      install_from_source    => true,
      source_url             => "http://${::puppet_server}:81/tomcat/apache-tomcat-${tomcat_version}.tar.gz",
      source_strip_first_dir => true,
      catalina_base          => $catalina_dir,
      catalina_home          => $catalina_dir,
    }

  }

  $tomcat_other_versions.each |String $version| {
    if $deploy_sample_app == true {

      service {"tomcat-plsample-tomcat${version}":
        ensure => stopped,
        status => "ps aux | grep \'catalina.base=/opt/apache-tomcat${version}\' | grep -v grep",
        stop   => "su -s /bin/bash -c \'/opt/apache-tomcat${version}/bin/catalina.sh stop tomcat\'",
        before => File["/opt/apache-tomcat${version}"],
      }

      file {"/opt/apache-tomcat${version}":
        ensure => absent,
        force  => true,
        backup => false,
        before => Tomcat::Service["plsample-tomcat${tomcat_version}"],
      }

    } else {

      file {"/opt/apache-tomcat${version}":
        ensure => absent,
        force  => true,
        backup => false,
      }

    }

  }

}
