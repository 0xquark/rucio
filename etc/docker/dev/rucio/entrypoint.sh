#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright European Organization for Nuclear Research (CERN) since 2012
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

CFG_PATH="$RUCIO_SOURCE_DIR"/etc/docker/test/extra/
if [ -z "$RUCIO_HOME" ]; then
    RUCIO_HOME=/opt/rucio
fi

mkdir -p "$RUCIO_HOME/etc"

echo "Setting up environment for Rucio..."

# Install git for policy package installation
echo "Installing git..."
dnf install -y git

# Install Python requirements first
if [ -d "$RUCIO_SOURCE_DIR/requirements" ]; then
    echo "Installing Python requirements..."
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel
    python3 -m pip install --no-cache-dir -r "$RUCIO_SOURCE_DIR/requirements/requirements.server.txt"
    python3 -m pip install --no-cache-dir -r "$RUCIO_SOURCE_DIR/requirements/requirements.dev.txt"
fi

# Add Rucio to Python path and install it in development mode
if [ -d "$RUCIO_HOME/lib" ]; then
    echo "Setting up Rucio Python path..."
    
    # Create .pth file in the virtual environment site-packages to add Rucio to Python path
    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
    echo "$RUCIO_HOME/lib" > "$SITE_PACKAGES/rucio.pth"
    
    # Install Rucio in development mode
    echo "Installing Rucio in development mode..."
    cd "$RUCIO_SOURCE_DIR"
    python3 -m pip install -e .
    
    # Verify installation
    python3 -c "import rucio; print('Rucio version:', rucio.version.version_string())" || {
        echo "ERROR: Rucio installation failed. Trying alternative approach..."
        PYTHONPATH=$RUCIO_HOME/lib:$PYTHONPATH
        export PYTHONPATH
        python3 -c "import rucio; print('Rucio version (via PYTHONPATH):', rucio.version.version_string())"
    }
fi

generate_rucio_cfg(){
    local override=$1
    local destination=$2

    python3 $RUCIO_SOURCE_DIR/tools/merge_rucio_configs.py --use-env \
        -s "$CFG_PATH"/rucio_autotests_common.cfg "$override" \
        -d "$destination"
}

if [ -f /tmp/usercert.pem ]; then
    cp /tmp/usercert.pem "$RUCIO_HOME/etc/"
fi
if [ -f /tmp/userkey.pem ]; then
    cp /tmp/userkey.pem "$RUCIO_HOME/etc/"
    chmod og-rwx "$RUCIO_HOME/etc/userkey.pem"
fi

echo "Generating alembic.ini and rucio.cfg"

if [ -z "$RDBMS" ]; then
    cp "$CFG_PATH"/rucio_default.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_default.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "oracle" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_oracle.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_oracle.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "mysql8" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_mysql8.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_mysql8.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "sqlite" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_sqlite.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_sqlite.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "postgres14" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_postgres14.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_postgres14.ini $RUCIO_HOME/etc/alembic.ini

fi

update-ca-trust

# Verify SQLAlchemy is installed
echo "Verifying SQLAlchemy installation..."
python3 -c "import sqlalchemy; print('SQLAlchemy version:', sqlalchemy.__version__)" || {
    echo "ERROR: SQLAlchemy not installed. Installing again..."
    python3 -m pip install --no-cache-dir sqlalchemy
}

echo "Environment setup complete, starting command..."
exec "$@"
