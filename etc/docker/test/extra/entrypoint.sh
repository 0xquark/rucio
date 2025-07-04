#!/bin/bash
set -e

# Copy necessary files from the mounted source to the container
if [ -d "/rucio-source" ]; then
  echo "Installing Rucio from mounted source code at /rucio-source"
  
  # Create directories if they don't exist
  mkdir -p /opt/rucio
  
  # Copy source code directories to /opt/rucio
  cp -r /rucio-source/lib /opt/rucio/
  cp -r /rucio-source/bin /opt/rucio/
  cp -r /rucio-source/tools /opt/rucio/
  cp -r /rucio-source/etc /opt/rucio/
  cp -r /rucio-source/tests /opt/rucio/
  
  # Install Rucio in editable mode from the mounted source
  cd /rucio-source
  pip install -e .[oracle,postgresql,mysql,kerberos,saml,dev]
  
  # Set up necessary certificates
  if [ -f "/rucio-source/etc/certs/hostcert_rucio.pem" ]; then
    cp /rucio-source/etc/certs/hostcert_rucio.pem /etc/grid-security/hostcert.pem
    cp /rucio-source/etc/certs/hostcert_rucio.key.pem /etc/grid-security/hostkey.pem
    chmod 0400 /etc/grid-security/hostkey.pem
  fi
  
  # Copy httpd configuration files
  if [ -f "/rucio-source/etc/docker/test/extra/httpd.conf" ]; then
    cp /rucio-source/etc/docker/test/extra/httpd.conf /etc/httpd/conf/httpd.conf
  fi
  
  if [ -f "/rucio-source/etc/docker/test/extra/rucio.conf" ]; then
    cp /rucio-source/etc/docker/test/extra/rucio.conf /etc/httpd/conf.d/rucio.conf
  fi
  
  if [ -f "/rucio-source/etc/docker/test/extra/00-mpm.conf" ]; then
    cp /rucio-source/etc/docker/test/extra/00-mpm.conf /etc/httpd/conf.modules.d/00-mpm.conf
  fi
  
  # Clean up any existing SSL configs
  rm -f /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/autoindex.conf /etc/httpd/conf.d/userdir.conf /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/zgridsite.conf
  
  # Copy additional certificate files
  if [ -f "/rucio-source/etc/certs/rucio_ca.pem" ]; then
    cp /rucio-source/etc/certs/rucio_ca.pem /opt/rucio/etc/rucio_ca.pem
  fi
  
  if [ -f "/rucio-source/etc/certs/ruciouser.pem" ]; then
    cp /rucio-source/etc/certs/ruciouser.pem /opt/rucio/etc/ruciouser.pem
  fi
  
  if [ -f "/rucio-source/etc/certs/ruciouser.key.pem" ]; then
    cp /rucio-source/etc/certs/ruciouser.key.pem /opt/rucio/etc/ruciouser.key.pem
    chmod 0400 /opt/rucio/etc/ruciouser.key.pem
  fi
  
  echo "Rucio installation from mounted source completed"
else
  echo "ERROR: No source code mounted at /rucio-source"
  exit 1
fi

# Execute the command passed to the container
exec "$@" 