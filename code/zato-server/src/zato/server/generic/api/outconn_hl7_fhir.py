# -*- coding: utf-8 -*-

"""
Copyright (C) 2022, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

# stdlib
from base64 import b64encode
from logging import getLogger
from traceback import format_exc

# FHIR-py
from fhirpy import SyncFHIRClient

# Zato
from zato.common.api import HL7
from zato.server.connection.queue import Wrapper
from zato.common.typing_ import cast_

# ################################################################################################################################
# ################################################################################################################################

if 0:
    from zato.common.typing_ import stranydict

# ################################################################################################################################
# ################################################################################################################################

logger = getLogger(__name__)

# ################################################################################################################################
# ################################################################################################################################

_basic_auth = HL7.Const.FHIR_Auth_Type.Basic_Auth.id
_jwt = HL7.Const.FHIR_Auth_Type.JWT.id

# ################################################################################################################################
# ################################################################################################################################

class _HL7FHIRConnection:
    conn: 'SyncFHIRClient'
    config: 'stranydict'

    def __init__(self, config:'stranydict') -> 'None':
        self.config = config
        self.conn = self.build_connection()

# ################################################################################################################################

    def build_connection(self) -> 'SyncFHIRClient':

        address = self.config['address']
        auth_header = self.build_basic_auth_header()

        conn = SyncFHIRClient(address, authorization=auth_header)
        return conn

# ################################################################################################################################

    def build_basic_auth_header(self) -> 'str':

        username = self.config['username']
        password = self.config['secret']

        auth_header = f'{username}:{password}'
        auth_header = auth_header.encode('ascii')
        auth_header = b64encode(auth_header)
        auth_header = auth_header.decode('ascii')
        auth_header = f'Basic {auth_header}'

        return auth_header

# ################################################################################################################################

    def build_jwt_header(self) -> 'str':
        pass

# ################################################################################################################################

    def ping(self):
        self.conn.execute('/', 'get')

# ################################################################################################################################
# ################################################################################################################################

class OutconnHL7FHIRWrapper(Wrapper):
    """ Wraps a queue of connections to HL7 FHIR servers.
    """
    def __init__(self, config, server):
        config.auth_url = config.address
        super(OutconnHL7FHIRWrapper, self).__init__(config, 'HL7 FHIR', server)

# ################################################################################################################################

    def add_client(self):

        try:
            conn = _HL7FHIRConnection(self.config)
            self.client.put_client(conn)
        except Exception:
            logger.warning('Caught an exception while adding an HL7 FHIR client (%s); e:`%s`',
                self.config.name, format_exc())

# ################################################################################################################################

    def delete(self, ignored_reason=None):
        pass

# ################################################################################################################################

    def ping(self):
        with self.client() as client:
            client = cast_('OutconnHL7FHIRWrapper', client)
            client.ping()

# ################################################################################################################################
# ################################################################################################################################
