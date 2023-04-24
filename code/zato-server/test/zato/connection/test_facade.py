# -*- coding: utf-8 -*-

"""
Copyright (C) 2023, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

# Must come first
from gevent.monkey import patch_all
_ = patch_all()

# stdlib
import os
import logging
from unittest import main, TestCase

# ################################################################################################################################
# ################################################################################################################################

if 0:
    pass

# ################################################################################################################################
# ################################################################################################################################

log_format = '%(asctime)s - %(levelname)s - %(name)s:%(lineno)d - %(message)s'
logging.basicConfig(level=logging.INFO, format=log_format)

# ################################################################################################################################
# ################################################################################################################################

class ModuleCtx:
    Env_Key_Should_Test = 'Zato_Test_REST_Facade'

# ################################################################################################################################
# ################################################################################################################################

class RESTFacadeTestCase(TestCase):

    def test_api_before_facade(self):
        if not os.environ.get(ModuleCtx.Env_Key_Should_Test):
            return

# ################################################################################################################################
# ################################################################################################################################

if __name__ == '__main__':
    _ = main()

# ################################################################################################################################
# ################################################################################################################################
