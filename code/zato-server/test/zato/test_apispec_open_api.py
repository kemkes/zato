# -*- coding: utf-8 -*-

"""
Copyright (C) 2020, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

from __future__ import absolute_import, division, print_function, unicode_literals

# stdlib
from unittest import main, TestCase


# Zato
from zato.server.apispec import ServiceInfo
from zato.server.apispec.openapi import OpenAPIGenerator
from common import MyService, service_name, sio_config

# ################################################################################################################################
# ################################################################################################################################

class OpenAPITestCase(TestCase):

    def test_generate_open_api(self):

        info = ServiceInfo(service_name, MyService, sio_config, 'public')
        channel_data = []
        needs_api_invoke = True
        needs_rest_channels = True
        api_invoke_path = '/my.api_invoke_path'

        generator = OpenAPIGenerator(info, channel_data, needs_api_invoke, needs_rest_channels, api_invoke_path)
        result = generator.generate()

        print(111, result)

# ################################################################################################################################
# ################################################################################################################################

if __name__ == '__main__':
    main()

# ################################################################################################################################
