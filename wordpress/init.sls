{%- set dget = salt['defaults.get'] %}
{%- load_yaml as wp %}
database: {{ dget('database') }}
username: {{ dget('username') }}
password: {{ dget('password') }}
owner:    {{ dget('owner') }}
path:     {{ dget('path') }}
frontend: {{ dget('frontend') }}
{%- endload %}

include:
  - nginx.ng
  - php.fpm
  # Including mysql.database to bring in dependencies for the
  # wordpress-database state.
  - mysql.database
  - mysql.server

extend:
  mysqld:
    service:
      - require_in:
        - mysql_database: wordpress-database
        - mysql_user: wordpress-database
        - mysql_grants: wordpress-database

wordpress-packages:
  pkg.installed:
    - pkgs:
      - wordpress

wordpress-path:
  file.directory:
    - name: {{ wp.path }}
    - user: {{ wp.owner }}
    - group: {{ wp.owner }}
    - makedirs: True

wordpress-database:
  mysql_database.present:
    - name: {{ wp.database }}
  mysql_user.present:
    - name: {{ wp.username }}
    - host: localhost
    - password: {{ wp.password }}
  mysql_grants.present:
    - database: {{ wp.database }}.*
    - grant: all privileges
    - user: {{ wp.username }}
    - host: localhost
    - require:
      - mysql_database: {{ wp.database }}
      - mysql_user: {{ wp.username }}

wordpress-keys-file:
  cmd.run:
    - name: >
        /usr/bin/curl
        -s -o {{ wp.path }}/wp-keys.php
        https://api.wordpress.org/secret-key/1.1/salt/
        && /bin/sed -i "1i\\<?php" {{ wp.path }}/wp-keys.php
        && chown -R {{ wp.owner }}:{{ wp.owner }} {{ wp.path }}
    - unless: test -e {{ wp.path }}/wp-keys.php
    - require:
      - file: wordpress-path
  
wordpress-config:
  file.managed:
    - name: {{ wp.path }}/wp-config.php
    - source: salt://wordpress/files/wp-config.php
    - mode: 0644
    - user: {{ wp.owner }}
    - group: {{ wp.owner }}
    - template: jinja
    - makedirs: True
    - context:
        username: {{ wp.username }}
        database: {{ wp.database }}
        password: {{ wp.password }}
    - require:
      - pkg: wordpress-packages
      - cmd: wordpress-keys-file
