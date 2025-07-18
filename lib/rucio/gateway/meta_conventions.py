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

from typing import TYPE_CHECKING, Optional, Union

from rucio.common.constants import DEFAULT_VO
from rucio.common.exception import AccessDenied
from rucio.core import meta_conventions
from rucio.db.sqla.constants import DatabaseOperationType
from rucio.db.sqla.session import db_session
from rucio.gateway.permission import has_permission

if TYPE_CHECKING:
    from rucio.common.types import InternalAccount
    from rucio.db.sqla.constants import KeyType


def list_keys() -> list[str]:
    """
    Lists all keys for DID Metadata Conventions.

    :returns: A list containing all keys.
    """
    with db_session(DatabaseOperationType.READ) as session:
        return meta_conventions.list_keys(session=session)


def list_values(key: str) -> list[str]:
    """
    Lists all allowed values for a DID key (all values for a key in DID Metadata Conventions).

    :param key: the name for the key.

    :returns: A list containing all values.
    """
    with db_session(DatabaseOperationType.READ) as session:
        return meta_conventions.list_values(key=key, session=session)


def add_key(
    key: str,
    key_type: Union["KeyType", str],
    issuer: "InternalAccount",
    value_type: Optional[str] = None,
    value_regexp: Optional[str] = None,
    vo: str = DEFAULT_VO,
) -> None:
    """
    Add an allowed key for DID metadata (update the DID Metadata Conventions table with a new key).

    :param key: the name for the new key.
    :param key_type: the type of the key: all(container, dataset, file), collection(dataset or container), file, derived(compute from file for collection).
    :param issuer: The issuer account.
    :param value_type: the type of the value, if defined.
    :param value_regexp: the regular expression that values should match, if defined.
    :param vo: The vo to act on
    """
    kwargs = {'key': key, 'key_type': key_type, 'value_type': value_type, 'value_regexp': value_regexp}
    with db_session(DatabaseOperationType.WRITE) as session:
        auth_result = has_permission(issuer=issuer, vo=vo, action='add_key', kwargs=kwargs, session=session)
        if not auth_result.allowed:
            raise AccessDenied('Account %s can not add key. %s' % (issuer, auth_result.message))
        return meta_conventions.add_key(key=key, key_type=key_type, value_type=value_type, value_regexp=value_regexp, session=session)


def add_value(key: str, value: str, issuer: "InternalAccount", vo: str = DEFAULT_VO) -> None:
    """
    Add an allowed value for DID metadata (update a key in DID Metadata Conventions table).

    :param key: the name for the key.
    :param value: the value.
    :param vo: the vo to act on.
    """
    kwargs = {'key': key, 'value': value}
    with db_session(DatabaseOperationType.WRITE) as session:
        auth_result = has_permission(issuer=issuer, vo=vo, action='add_value', kwargs=kwargs, session=session)
        if not auth_result.allowed:
            raise AccessDenied('Account %s can not add value %s to key %s. %s' % (issuer, value, key, auth_result.message))
        return meta_conventions.add_value(key=key, value=value, session=session)
