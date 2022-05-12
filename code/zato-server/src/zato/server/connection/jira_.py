# -*- coding: utf-8 -*-

# atlassian-python-api
from atlassian import Jira as AtlassianJiraClient


# ################################################################################################################################
# ################################################################################################################################

if 0:
    from zato.common.typing_ import stranydict

# ################################################################################################################################
# ################################################################################################################################

class JiraClient(AtlassianJiraClient):

    zato_api_version: 'str'
    zato_address: 'str'
    zato_username: 'str'
    zato_token: 'str'
    zato_is_cloud: 'bool'

    def __init__(
        self,
        *,
        zato_api_version, # type: str
        zato_address, # type: str
        zato_username, # type: str
        zato_token, # type: str
        zato_is_cloud, # type: bool
    ) -> 'None':

        self.zato_api_version = zato_api_version
        self.zato_address = zato_address
        self.zato_username = zato_username
        self.zato_token = zato_token
        self.zato_is_cloud = zato_is_cloud

        super().__init__(
            url = self.zato_address,
            username = self.zato_username,
            token = self.zato_token,
            api_version = self.zato_api_version,
            cloud = self.zato_is_cloud,
        )

# ################################################################################################################################

    @staticmethod
    def from_config(config:'stranydict') -> 'JiraClient':
        return JiraClient(
            zato_api_version = config['api_version'],
            zato_address = config['address'],
            zato_username = config['username'],
            zato_token = config['secret'],
            zato_is_cloud = config['is_cloud'],
        )

# ################################################################################################################################
# ################################################################################################################################
