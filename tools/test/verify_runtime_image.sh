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

# This script verifies that the runtime image setup works correctly by:
# 1. Checking if the Python path is set up correctly
# 2. Verifying that the rucio module can be imported
# 3. Testing a simple rucio operation

set -e

echo "Verifying runtime image setup..."

# Check Python path
echo "Checking Python path..."
python3 -c "import sys; print(sys.path)"

# Check if rucio module can be imported
echo "Checking if rucio module can be imported..."
python3 -c "import rucio; print(f'Rucio module found at: {rucio.__file__}')"

# Test a simple rucio operation
echo "Testing a simple rucio operation..."
python3 -c "from rucio.common.config import config_get; print(f'Rucio config section names: {config_get().sections()}')"

echo "Runtime image setup verified successfully!" 