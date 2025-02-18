---
haproxy:
  # use lookup section to override 'map.jinja' values
  # lookup:
  #   user: 'custom-user'
  #   group: 'custom-group'
  #   new setting to override configuration file path
  #   config_file: /etc/haproxy/haproxy.cfg
  enabled: true
  # Overwrite an existing config file if present
  # (default behaviour unless set to false)
  overwrite: true
  # old setting to override configuration file path, kept for compatibility
  # config_file_path: /etc/haproxy/haproxy.cfg
  global:
    log:
      - 127.0.0.1 local2
      - 127.0.0.1 local1 notice
    # Option log-tag parameter, sets the tag field in the syslog header
    log-tag: haproxy
    # Optional log-send-hostname parameter, sets the hostname field in the syslog header
    log-send-hostname: localhost
    stats:
      enable: true
      # Using the `haproxy:global:chroot:path`
      socketpath: /var/lib/haproxy/stats
      mode: 660
      level: admin
      # yamllint disable-line rule:line-length
      # Optional extra bind parameter, for example to set the owner/group on the socket file
      extra: user haproxy group haproxy
    # yamllint disable-line rule:line-length
    ssl-default-bind-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384"
    ssl-default-bind-options: "no-sslv3 no-tlsv10 no-tlsv11"

    user: haproxy
    group: haproxy
    chroot:
      enable: true
      path: /var/lib/haproxy

    daemon: true


  userlists:
    userlist1:
      users:
        john: insecure-password doe
        sam: insecure-password frodo

  defaults:
    log: global
    mode: http
    retries: 3
    options:
      - httplog
      - dontlognull
      - forwardfor
      - http-server-close
    # yamllint disable-line rule:line-length
    logformat: "%ci:%cp\\ [%t]\\ %ft\\ %b/%s\\ %Tq/%Tw/%Tc/%Tr/%Tt\\ %ST\\ %B\\ %CC\\ %CS\\ %tsc\\ %ac/%fc/%bc/%sc/%rc\\ %sq/%bq\\ %hr\\ %hs\\ %{+Q}r"
    timeouts:
      - http-request    10s
      - queue           1m
      - connect         10s
      - client          1m
      - server          1m
      - http-keep-alive 10s
      - check           10s
    stats:
      - enable
      - uri: '/admin?stats'
      - realm: 'Haproxy\ Statistics'
      - auth: 'admin1:AdMiN123'


  listens:
    stats:
      bind:
        - "0.0.0.0:8998"
      mode: http
      options:
        - httpchk
      httpcheck: disable-on-404
      stats:
        enable: true
        uri: "/admin?stats"
        refresh: "20s"
    myservice:
      bind:
        - "*:8888"
      options:
        - forwardfor
        - http-server-close
        - httpchk
      defaultserver:
        slowstart: 60s
        maxconn: 256
        maxqueue: 128
        weight: 100
      httpchecks:
        - send-state
        - expect status 200
      servers:
        web1:
          host: web1.example.com
          port: 80
          check: check
        web2:
          host: web2.example.com
          port: 18888
          check: check
        web3:
          host: web3.example.com
    redis:
      bind:
        - '*:6379'
      balance: roundrobin
      defaultserver:
        fall: 3
      options:
        - tcp-check
      tcpchecks:
        - send PINGrn
        - expect string +PONG
        - expect string role:master
        - send QUITrn
        - expect string +OK
      servers:
        server1:
          host: server1
          port: 6379
          check: check
          extra: port 6379 inter 1s
        server2:
          host: server2
          port: 6379
          check: check
          extra: port 6379 inter 1s backup
  frontends:
    frontend1:
      name: www-http
      bind: "*:80"
      redirects:
        - scheme https if !{ ssl_fc }
      reqadds:
        - "X-Forwarded-Proto http"
      default_backend: www-backend

  # www-https:
  #   bind: "*:443 ssl crt /etc/ssl/private/certificate-chain-and-key-combined.pem"
  # yamllint disable-line rule:line-length
  #   logformat: "%ci:%cp\\ [%t]\\ %ft\\ %b/%s\\ %Tq/%Tw/%Tc/%Tr/%Tt\\ %ST\\ %B\\ %CC\\ %CS\\ %tsc\\ %ac/%fc/%bc/%sc/%rc\\ %sq/%bq\\ %hr\\ %hs\\ %{+Q}r\\ ssl_version:%sslv\\ ssl_cipher:%sslc"
  #   reqadds:
  #        - "X-Forwarded-Proto https"
  #      default_backend: www-backend
  #      acls:
  #        - url_static       path_beg       -i /static /images /javascript /stylesheets
  #        - url_static       path_end       -i .jpg .gif .png .css .js
  #      use_backends:
  #        - static-backend  if url_static
  #      extra: "rspadd  Strict-Transport-Security:\ max-age=15768000"
  #    some-services:
  #      bind:
  #        - "*:8080"
  #        - "*:8088"
  #      default_backend: api-backend

  backends:
    backend1:
      name: www-backend
      balance: roundrobin
      extra: "http-request del-header ^X-Forwarded-For:"
      redirects:
        - scheme https if !{ ssl_fc }
      servers:
        server1:
          name: server1-its-name
          host: 192.168.1.213
          port: 80
          check: check
    static-backend:
      balance: roundrobin
      redirects:
        - scheme https if !{ ssl_fc }
      options:
        - http-server-close
        - httpclose
        - forwardfor    except 127.0.0.0/8
        - httplog
      cookie: "pm insert indirect"
      stats:
        enable: true
        uri: /url/to/stats
        realm: LoadBalancer
        auth: "user:password"
      servers:
        some-server:
          host: 123.156.189.111
          port: 8080
          check: check
        another-server:
          host: 123.156.189.112
    api-backend:
      options:
        - http-server-close
        - forwardfor
      servers:
        apiserver1:
          host: apiserver1.example.com
          port: 80
          check: check
