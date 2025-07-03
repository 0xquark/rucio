#!/usr/bin/env python3
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

import os
import sys
import site
import subprocess

def print_header(text):
    print("\n" + "=" * 60)
    print(text)
    print("=" * 60)

def main():
    print_header("PYTHON ENVIRONMENT DEBUG INFO")
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"PYTHONPATH: {os.environ.get('PYTHONPATH', 'Not set')}")
    print(f"RUCIO_SOURCE_DIR: {os.environ.get('RUCIO_SOURCE_DIR', 'Not set')}")
    print(f"RUCIO_HOME: {os.environ.get('RUCIO_HOME', 'Not set')}")
    
    print_header("PYTHON SITE PACKAGES")
    print(f"Site packages: {site.getsitepackages()}")
    
    print_header("INSTALLED PACKAGES")
    try:
        subprocess.run([sys.executable, "-m", "pip", "list"], check=True)
    except subprocess.CalledProcessError:
        print("Error running pip list")
    
    print_header("IMPORT TEST")
    modules_to_test = ['sqlalchemy', 'alembic', 'flask', 'rucio']
    for module in modules_to_test:
        try:
            __import__(module)
            print(f"✓ Successfully imported {module}")
        except ImportError as e:
            print(f"✗ Failed to import {module}: {e}")
    
    print_header("PYTHON PATH")
    for i, path in enumerate(sys.path):
        print(f"{i}: {path}")
    
    print_header("END DEBUG INFO")

if __name__ == "__main__":
    main() 