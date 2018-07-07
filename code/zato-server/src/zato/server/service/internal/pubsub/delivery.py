# -*- coding: utf-8 -*-

"""
Copyright (C) 2018, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

from __future__ import absolute_import, division, print_function, unicode_literals

# stdlib
from json import dumps

# Zato
from zato.common import PUBSUB
from zato.common.broker_message import PUBSUB as BROKER_MSG_PUBSUB
from zato.common.exception import BadRequest
from zato.common.pubsub import HandleNewMessageCtx
from zato.server.pubsub.task import PubSubTool
from zato.server.service import Int, Opaque
from zato.server.service.internal import AdminService, AdminSIO

# ################################################################################################################################

class NotifyPubSubMessage(AdminService):
    """ Notifies pubsub about new messages available. It is guaranteed that this service will be always invoked
    on the server where each sub_key from sub_key_list exists.
    """
    def handle(self):
        # The request that we have on input needs to be sent to a pubsub_tool for each sub_key,
        # even if it is possibly the same pubsub_tool for more than one input sub_key.
        req = self.request.raw_request['request']

        for sub_key in req['sub_key_list']:
            pubsub_tool = self.pubsub.pubsub_tool_by_sub_key[sub_key]
            pubsub_tool.handle_new_messages(HandleNewMessageCtx(self.cid, req['has_gd'], [sub_key],
                req['non_gd_msg_list'], req['is_bg_call'], req['pub_time_max']))

# ################################################################################################################################

class CreateDeliveryTask(AdminService):
    """ Starts a new delivery task for endpoints other than WebSockets (which are handled separately).
    """
    def handle(self):
        config = self.request.raw_request

        # Creates a pubsub_tool that will handle this subscription and registers it with pubsub
        pubsub_tool = PubSubTool(self.pubsub, self.server, config['endpoint_type'])

        # Makes this sub_key known to pubsub
        pubsub_tool.add_sub_key(config['sub_key'])

        # Common message for both local server and broker
        msg = {
            'cluster_id': self.server.cluster_id,
            'server_name': self.server.name,
            'server_pid': self.server.pid,
            'sub_key': config['sub_key'],
            'endpoint_type': config['endpoint_type'],
            'task_delivery_interval': config['task_delivery_interval'],
        }

        # Register this delivery task with current server's pubsub but only if we do not have it already.
        # It is possible that we do, for instance:
        #
        # 1) This server had this task when it was starting up
        # 2) The task was migrated to another server
        #
        different_cluster = config.cluster_id != self.server.cluster_id
        different_server = config.server_id != self.server.id
        different_pid = config.server_pid != self.server.pid

        if different_cluster and different_server and different_pid:
            self.pubsub.set_sub_key_server(msg)

        # Update in-RAM state of workers
        msg['action'] = BROKER_MSG_PUBSUB.SUB_KEY_SERVER_SET.value
        self.broker_client.publish(msg)

# ################################################################################################################################

class DeliverMessage(AdminService):
    """ Callback service invoked by delivery tasks for each message or a list of messages that need to be delivered
    to a given endpoint.
    """
    class SimpleIO(AdminSIO):
        input_required = (Opaque('msg'), Opaque('subscription'))

# ################################################################################################################################

    def handle(self):
        msg = self.request.input.msg

        subscription = self.request.input.subscription
        endpoint_impl_getter = self.pubsub.endpoint_impl_getter[subscription.config.endpoint_type]

        func = deliver_func[subscription.config.endpoint_type]
        func(self, msg, subscription, endpoint_impl_getter)

# ################################################################################################################################

    def _get_data_from_message(self, msg):

        # A list of messages is given on input so we need to serialize each of them individually
        if isinstance(msg, list):
            return [elem.to_external_dict() for elem in msg]

        # A single message was given on input
        else:
            return msg.to_external_dict()

# ################################################################################################################################

    def _deliver_rest_soap(self, msg, subscription, impl_getter):
        if not subscription.config.out_http_soap_id:
            raise ValueError('Missing out_http_soap_id for subscription `{}`'.format(subscription))
        else:
            data = self._get_data_from_message(msg)
            endpoint = impl_getter(subscription.config.out_http_soap_id)
            endpoint.conn.http_request(subscription.config.out_http_method, self.cid, data=data)

# ################################################################################################################################

    def _deliver_amqp(self, msg, subscription, _ignored_impl_getter):

        # Ultimately we should use impl_getter to get the outconn
        for value in self.server.worker_store.worker_config.out_amqp.itervalues():
            if value['config']['id'] == subscription.config.out_amqp_id:

                data = self._get_data_from_message(msg)
                name = value['config']['name']
                kwargs = {}

                if subscription.config.amqp_exchange:
                    kwargs['exchange'] = subscription.config.amqp_exchange

                if subscription.config.amqp_routing_key:
                    kwargs['routing_key'] = subscription.config.amqp_routing_key

                self.outgoing.amqp.send(dumps(data), name, **kwargs)

                # We found our outconn and the message was sent, we can stop now
                break

# ################################################################################################################################

    def _deliver_wsx(self, msg, subscription, _ignored):
        raise NotImplementedError('WSX deliveries should be handled by each socket\'s deliver_pubsub_msg')

# ################################################################################################################################

# We need to register it here because it refers to DeliverMessage's methods
deliver_func = {
    PUBSUB.ENDPOINT_TYPE.AMQP.id: DeliverMessage._deliver_amqp,
    PUBSUB.ENDPOINT_TYPE.REST.id: DeliverMessage._deliver_rest_soap,
    PUBSUB.ENDPOINT_TYPE.SOAP.id: DeliverMessage._deliver_rest_soap,
    PUBSUB.ENDPOINT_TYPE.WEB_SOCKETS.id: DeliverMessage._deliver_wsx,
}

# ################################################################################################################################

class GetServerPIDForSubKey(AdminService):
    """ Returns PID of a server process for input sub_key.
    """
    class SimpleIO(AdminSIO):
        input_required = ('sub_key',)
        output_optional = (Int('server_pid'),)

# ################################################################################################################################

    def _raise_bad_request(self, sub_key):
        raise BadRequest(self.cid, 'No such sub_key found `{}`'.format(sub_key))

# ################################################################################################################################

    def handle(self):
        sub_key = self.request.input.sub_key
        try:
            server = self.pubsub.get_delivery_server_by_sub_key(sub_key, False)
        except KeyError:
            self._raise_bad_request(sub_key)
        else:
            if server:
                self.response.payload.server_pid = server.server_pid
            else:
                self._raise_bad_request(sub_key)

# ################################################################################################################################
