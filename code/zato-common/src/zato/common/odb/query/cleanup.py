# -*- coding: utf-8 -*-

"""
Copyright (C) 2022, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

# stdlib
from logging import getLogger

# SQLAlchemy
from sqlalchemy import delete, func, or_

# Zato
from zato.common.odb.model import PubSubEndpoint, PubSubEndpointEnqueuedMessage, PubSubMessage, PubSubSubscription

# ################################################################################################################################
# ################################################################################################################################

if 0:
    from sqlalchemy.orm.session import Session as SASession
    from zato.common.typing_ import anylist, strlist

# ################################################################################################################################
# ################################################################################################################################

logger = getLogger('zato_pubsub.sql')

# ################################################################################################################################
# ################################################################################################################################

QueueTable   = PubSubEndpointEnqueuedMessage.__table__
MessageTable = PubSubMessage.__table__

# ################################################################################################################################
# ################################################################################################################################

def get_subscriptions(task_id:'str', session:'SASession', max_last_interaction_time:'float') -> 'anylist':

    logger.info('%s: Getting subscriptions with max_last_interaction_time `%s`', task_id, max_last_interaction_time)

    result = session.query(
        PubSubSubscription.id,
        PubSubSubscription.sub_key,
        PubSubSubscription.ext_client_id,
        PubSubSubscription.last_interaction_time,
        PubSubEndpoint.name.label('endpoint_name'),
        PubSubEndpoint.id.label('endpoint_id'),
        ).\
        filter(PubSubEndpoint.id == PubSubSubscription.endpoint_id).\
        filter(PubSubEndpoint.is_internal.is_(False)).\
        filter(or_(
            PubSubSubscription.last_interaction_time < max_last_interaction_time,
            PubSubSubscription.last_interaction_time.is_(None),
        )).\
        order_by(PubSubSubscription.last_interaction_time.asc()).\
        all()

    return result

# ################################################################################################################################
# ################################################################################################################################

def get_messages(task_id:'str', session:'SASession', topic_id:'int', topic_name:'str') -> 'anylist':

    logger.info('%s: Getting messages for topic `%s`', task_id, topic_name)

    in_how_many_queues = func.count(PubSubEndpointEnqueuedMessage.pub_msg_id).label('in_how_many_queues')

    result = session.query(
        PubSubMessage.pub_msg_id,
        ).\
        group_by(PubSubMessage.pub_msg_id).\
        outerjoin(PubSubEndpointEnqueuedMessage, PubSubMessage.id==PubSubEndpointEnqueuedMessage.pub_msg_id).\
        having(in_how_many_queues == 0).\
        filter(PubSubMessage.topic_id == topic_id).\
        all()

    return result

# ################################################################################################################################
# ################################################################################################################################

def delete_queue_messages(session:'SASession', msg_id_list:'strlist') -> 'None':

    logger.info('Deleting %d queue message(s): %s', len(msg_id_list), msg_id_list)

    session.execute(
        delete(QueueTable).\
        where(
            QueueTable.c.pub_msg_id.in_(msg_id_list),
        )
    )

# ################################################################################################################################
# ################################################################################################################################

def delete_topic_messages(session:'SASession', msg_id_list:'strlist') -> 'None':

    logger.info('Deleting %d topic message(s): %s', len(msg_id_list), msg_id_list)

    session.execute(
        delete(MessageTable).\
        where(
            MessageTable.c.pub_msg_id.in_(msg_id_list),
        )
    )

# ################################################################################################################################
# ################################################################################################################################