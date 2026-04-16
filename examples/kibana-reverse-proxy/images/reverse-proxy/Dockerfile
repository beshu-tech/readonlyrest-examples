FROM httpd:2.4

# Enable required Apache modules
RUN sed -i \
    -e 's/^#\(LoadModule slotmem_shm_module modules\/mod_slotmem_shm.so\)/\1/' \
    -e 's/^#\(LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so\)/\1/' \
    -e 's/^#\(LoadModule proxy_module modules\/mod_proxy.so\)/\1/' \
    -e 's/^#\(LoadModule proxy_http_module modules\/mod_proxy_http.so\)/\1/' \
    -e 's/^#\(LoadModule proxy_wstunnel_module modules\/mod_proxy_wstunnel.so\)/\1/' \
    -e 's/^#\(LoadModule proxy_balancer_module modules\/mod_proxy_balancer.so\)/\1/' \
    -e 's/^#\(LoadModule lbmethod_byrequests_module modules\/mod_lbmethod_byrequests.so\)/\1/' \
    -e 's/^#\(LoadModule rewrite_module modules\/mod_rewrite.so\)/\1/' \
    -e 's/^#\(LoadModule headers_module modules\/mod_headers.so\)/\1/' \
    -e 's/^#\(LoadModule ssl_module modules\/mod_ssl.so\)/\1/' \
    /usr/local/apache2/conf/httpd.conf

RUN echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf \
 && echo "Listen 443" >> /usr/local/apache2/conf/httpd.conf

ARG REWRITE_BASE_PATH_BY_KIBANA=true
ENV REWRITE_BASE_PATH_BY_KIBANA=${REWRITE_BASE_PATH_BY_KIBANA}

COPY images/reverse-proxy/reverse-proxy.conf /usr/local/apache2/conf/extra/reverse-proxy.conf
COPY images/reverse-proxy/reverse-proxy-entrypoint.sh /usr/local/bin/reverse-proxy-entrypoint.sh

RUN echo "Include conf/extra/reverse-proxy.conf" >> /usr/local/apache2/conf/httpd.conf

COPY images/reverse-proxy/certs/ /usr/local/apache2/conf/certs/

EXPOSE 80 443
