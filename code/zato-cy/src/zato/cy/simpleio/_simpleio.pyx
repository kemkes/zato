# -*- coding: utf-8 -*-

"""
Copyright (C) 2018, Zato Source s.r.o. https://zato.io

Licensed under LGPLv3, see LICENSE.txt for terms and conditions.
"""

from __future__ import absolute_import, division, print_function, unicode_literals

# stdlib
import types
from decimal import Decimal as decimal_Decimal
from itertools import chain
from uuid import UUID as uuid_UUID

# datetutil
from dateutil.parser import parse as dt_parse

# Zato
from zato.common import DATA_FORMAT
from zato.util_convert import to_bool

# Zato - Cython
from zato.bunch import Bunch, bunchify

# ################################################################################################################################

_builtin_float = types.FloatType
_builtin_int = types.IntType
_list_like = (list, tuple)

# ################################################################################################################################

cdef class _NotGiven(object):
    """ Indicates that a particular value was not provided on input or output.
    """
    def __str__(self):
        return '<NotGiven>'

    def __bool__(self):
        return False # Always evaluates to a boolean False

# ################################################################################################################################

cdef class ParsingError(Exception):
    pass

# ################################################################################################################################

cdef enum ElemType:
    as_is         =  100
    bool          =  200
    csv           =  300
    date          =  400
    date_time     =  500
    decimal       =  500
    dict_         =  600
    dict_list     =  700
    float         =  800
    int           =  900
    list_         = 1000
    opaque        = 1100
    text          = 1200
    uuid          = 1300
    user_defined  = 1_000_000

# ################################################################################################################################

cdef class Elem(object):
    """ An individual input or output element. May be a ForceType instance or not.
    """
    cdef:
        public unicode name
        ElemType _type
        object _default
        public bint is_required

        public dict parse_from # From external formats to Python objects
        public dict parse_to   # From Python objects to external formats

# ################################################################################################################################

    def __cinit__(self):
        self._type = ElemType.as_is
        self.parse_from = {}
        self.parse_to = {}

        self.parse_from[DATA_FORMAT.JSON] = self.from_json
        self.parse_from[DATA_FORMAT.XML] = self.from_xml
        self.parse_from[DATA_FORMAT.CSV] = self.from_csv

        self.parse_to[DATA_FORMAT.JSON] = self.to_json
        self.parse_to[DATA_FORMAT.XML] = self.to_xml
        self.parse_to[DATA_FORMAT.CSV] = self.to_csv

# ################################################################################################################################

    def __init__(self, name):
        self.name = name

# ################################################################################################################################

    def __str__(self):
        return '<{} at {} {}:{} d:{} r:{}>'.format(self.__class__.__name__, hex(id(self)), self.name, self._type,
            self._default, self.is_required)

# ################################################################################################################################

    __repr__ = __str__

    def __cmp__(self, other):
        return self.name == other.name

# ################################################################################################################################

    def __hash__(self):
        return hash(self.name) # Names are always unique

# ################################################################################################################################

    @property
    def pretty(self):
        out = ''

        if not self.is_required:
            out += '-'

        out += self.name

        return out

# ################################################################################################################################

    @staticmethod
    def _not_implemented():
        raise NotImplementedError()

    from_json = _not_implemented
    to_json   = _not_implemented

    from_xml  = _not_implemented
    to_xml    = _not_implemented

    from_csv  = _not_implemented
    to_csv    = _not_implemented

# ################################################################################################################################

cdef class AsIs(Elem):
    def __cinit__(self):
        self._type = ElemType.as_is

    def from_json(self, data):
        return data

    to_json = from_json

# ################################################################################################################################

cdef class Bool(Elem):
    def __cinit__(self):
        self._type = ElemType.bool

    def from_json(self, value):
        return to_bool(value)

    from_xml = to_json = to_xml = from_json

# ################################################################################################################################

cdef class CSV(Elem):
    def __cinit__(self):
        self._type = ElemType.csv

    def from_json(self, value, *ignored):
        return value.split(',')

    from_xml = from_json

    def to_json(self, value, *ignored):
        return ','.join(value) if isinstance(value, (list, tuple)) else value

    to_xml = to_json

# ################################################################################################################################

cdef class Date(Elem):

    def __cinit__(self):
        self._type = ElemType.date

    def from_json(self, value):
        try:
            return dt_parse(value)
        except ValueError as e:
            # This is the only way to learn about what kind of exception we caught
            raise ValueError('Could not parse `{}` as a {} object ({})'.format(value, self.__class__.__name__, e.message))

# ################################################################################################################################

cdef class DateTime(Date):
    def __cinit__(self):
        self._type = ElemType.date_time

# ################################################################################################################################

cdef class Decimal(Elem):
    def __cinit__(self):
        self._type = ElemType.decimal

    def from_json(self, value):
        return decimal_Decimal(value)

# ################################################################################################################################

cdef class Dict(Elem):

    cdef:
        public set _keys_required
        public set _keys_optional

    def __cinit__(self):
        self._type = ElemType.dict_
        self._keys_required = set()
        self._keys_optional = set()

    def __init__(self, name, *args):
        self.name = name
        for key in args:
            self._keys_optional.add(key[1:]) if key.startswith('-') else self._keys_required.add(key)

# ################################################################################################################################

    @staticmethod
    def from_json_static(data, keys_required, keys_optional):
        if keys_required or keys_optional:

            # Output we will return
            out = {}

            # All the required keys
            for key in keys_required:
                value = data.get(key)
                if not value:
                    raise ValueError('Key `{}` not found in `{}`'.format(key, data))
                out[key] = value

            # All the optional keys
            for key in keys_optional:
                value = data.get(key)
                if value:
                    out[key] = value

            return out

        else:
            return data

# ################################################################################################################################

    def from_json(self, data):
        return Dict.from_json_static(data, self._keys_required, self._keys_optional)

# ################################################################################################################################

cdef class DictList(Dict):
    def __cinit__(self):
        self._type = ElemType.dict_list

    def from_json(self, value):
        out = []

        for elem in value:
            out.append(Dict.from_json_static(elem, self._keys_required, self._keys_optional))

        return out

# ################################################################################################################################

cdef class Float(Elem):
    def __cinit__(self):
        self._type = ElemType.float

    def from_json(self, value):
        return _builtin_float(value)

# ################################################################################################################################

cdef class Int(Elem):
    def __cinit__(self):
        self._type = ElemType.int

    def from_json(self, value):
        return _builtin_int(value)

# ################################################################################################################################

cdef class List(Elem):
    def __cinit__(self):
        self._type = ElemType.list_

    def from_json(self, value):
        return value if isinstance(value, _list_like) else [value]

# ################################################################################################################################

cdef class Opaque(Elem):
    def __cinit__(self):
        self._type = ElemType.opaque

    def from_json(self, value):
        return value

    from_xml = to_xml = from_json

# ################################################################################################################################

cdef class Text(Elem):

    cdef:
        public str encoding

    def __cinit__(self):
        self._type = ElemType.text

    def __init__(self, name, **kwargs):
        super(Text, self).__init__(name)
        self.encoding = kwargs.get('encoding', 'utf8')

    def from_json(self, value):
        return value if isinstance(value, basestring) else str(value).decode(self.encoding)

# ################################################################################################################################

cdef class UUID(Elem):

    def __cinit__(self):
        self._type = ElemType.uuid

    def from_json(self, value):
        return uuid_UUID(value)

# ################################################################################################################################

cdef class ConfigItem(object):
    """ An individual instance of server-wide SimpleIO configuration. Each subclass covers
    a particular set of exact values, prefixes or suffixes.
    """
    cdef:
        public set exact
        public set prefixes
        public set suffixes

    def __str__(self):
        return '<{} at {} e:{}, p:{}, s:{}>'.format(self.__class__.__name__, hex(id(self)),
            sorted(self.exact), sorted(self.prefixes), sorted(self.suffixes))

# ################################################################################################################################

cdef class BoolConfig(ConfigItem):
    """ SIO configuration for boolean values.
    """

# ################################################################################################################################

cdef class IntConfig(ConfigItem):
    """ SIO configuration for integer values.
    """

# ################################################################################################################################

cdef class SecretConfig(ConfigItem):
    """ SIO configuration for secret values, passwords, tokens, API keys etc.
    """

# ################################################################################################################################

cdef class _SIOServerConfig(object):
    """ Contains global SIO configuration. Each service's _sio attribute
    will refer to this object so as to have only one place where all the global configuration is kept.
    """
    cdef:
        public BoolConfig bool_config
        public IntConfig int_config
        public SecretConfig secret_config

        # Names in SimpleIO declarations that can be overridden by users
        public unicode input_required_name
        public unicode input_optional_name
        public unicode output_required_name
        public unicode output_optional_name
        public unicode default_value
        public unicode default_input_value
        public unicode default_output_value
        public unicode response_elem

        public unicode prefix_as_is     # a
        public unicode prefix_bool      # b
        public unicode prefix_csv       # c
        public unicode prefix_date      # dt
        public unicode prefix_date_time # dtm
        public unicode prefix_dict      # d
        public unicode prefix_dict_list # dl
        public unicode prefix_float     # f
        public unicode prefix_int       # i
        public unicode prefix_list      # l
        public unicode prefix_opaque    # o
        public unicode prefix_text      # t
        public unicode prefix_uuid      # u
        public unicode prefix_required  # +
        public unicode prefix_optional  # -

        # Global variables, can be always overridden on a per-declaration basis
        public object skip_empty_keys
        public object skip_empty_request_keys
        public object skip_empty_response_keys

    cdef bint is_int(self, name):
        """ Returns True if input name should be treated like ElemType.int.
        """

    cdef bint is_bool(self, name):
        """ Returns True if input name should be treated like ElemType.bool.
        """

    cdef bint is_secret(self, name):
        """ Returns True if input name should be treated like ElemType.secret.
        """

# ################################################################################################################################

cdef class SIOList(object):
    """ Represents one of input/output required/optional.
    """
    cdef:
        list elems

    def __cinit__(self):
        self.elems = []

    def __iter__(self):
        return iter(self.elems)

    def set_elems(self, elems):
        self.elems[:] = elems

    def get_elem_names(self):
        return sorted(elem.name for elem in self.elems)

# ################################################################################################################################

cdef class SIODefinition(object):
    """ A single SimpleIO definition attached to a service.
    """
    cdef:

        # A list of Elem items required on input
        public SIOList _input_required

        # A list of Elem items optional on input
        public SIOList _input_optional

        # A list of Elem items required on output
        public SIOList _output_required

        # A list of Elem items optional on output
        public SIOList _output_optional

        # Name of the service this definition is for
        unicode _service_name
        # Whether all non-NotGiven optional input elements should be skipped or not
        bint _skip_all_empty_request_keys

        # A list of non-NotGiven optional input elements to skip
        list _skip_empty_request_keys

        # Whether all non-NotGiven optional output elements should be skipped or not
        bint _skip_all_empty_response_keys

        # A list of non-NotGiven optional output elements to skip
        list _skip_empty_response_keys

        # Name of the response element, or None if there should be no top-level one
        object _response_elem

        # Default value to use for optional input elements, unless overridden on a per-element basis
        object _default_input_value

        # Default value to use for optional output elements, unless overridden on a per-element basis
        object _default_output_value

        object _default_value # Preserved for backward-compatibility, the same as _default_output_value

    def __cinit__(self):
        self._input_required = SIOList()
        self._input_optional = SIOList()
        self._output_required = SIOList()
        self._output_optional = SIOList()

    cdef list get_input_pretty(self):
        cdef list required = []
        cdef list optional = []
        cdef list out = []

        for item in self._input_required:
            print(item)

        return out

    cdef list get_output_pretty(self):
        cdef list required = []
        cdef list optional = []
        cdef list out = []

        return out

    def __str__(self):
        return '<{} at {}, input:`{}`, output:`{}`>'.format(self.__class__.__name__, hex(id(self)),
            self.get_input_pretty(), self.get_output_pretty())

# ################################################################################################################################

cdef class CySimpleIO(object):
    """ If a service uses SimpleIO then, during deployment, its class will receive an attribute called _sio
    based on the service's SimpleIO attribute. The _sio one will be an instance of this Cython class.
    """
    cdef:
        # Server-wide configuration
        _SIOServerConfig server_config

        # Current service's configuration, after parsing
        public SIODefinition definition

        # User-provided SimpleIO declaration, before parsing. This is parsed into self.definition.
        object user_declaration

# ################################################################################################################################

    def __cinit__(self, _SIOServerConfig server_config, object user_declaration):
        self.server_config = server_config
        self.definition = SIODefinition()
        self.user_declaration = user_declaration

# ################################################################################################################################

    cpdef build(self):
        """ Parses a user-defined SimpleIO declaration (currently, a Python class)
        and populates all the internal structures as needed.
        """
        self._build_io_elems('input')
        self._build_io_elems('output')

# ################################################################################################################################

    cdef Elem _convert_to_elem_instance(self, elem, container, is_required):

        # By default, we always return Text instances for elements that do not specify an SIO type
        cdef Text _elem

        _elem = Text(elem)
        _elem.name = elem
        _elem._default = self.definition._default_input_value if container == 'input' else self.definition._default_output_value
        _elem.is_required = is_required

        return _elem

# ################################################################################################################################

    cdef _build_io_elems(self, container):
        """ Returns I/O elems, e.g. input or input_required but first ensures that only correct elements are given in SimpleIO,
        e.g. if input is on input then input_required or input_optional cannot be.
        """
        required_name = '{}_required'.format(container)
        optional_name = '{}_optional'.format(container)

        plain = getattr(self.user_declaration, container, [])
        required = getattr(self.user_declaration, required_name, [])
        optional = getattr(self.user_declaration, optional_name, [])

        # If the plain element alone is given, we cannot have required or optional lists.
        if plain and (required or optional):
            if required and optional:
                details = '{}_required/{}_optional'.format(container, container)
            elif required:
                details = '{}_required'.format(container)
            elif optional:
                details = '{}_optional'.format(container)

            msg = 'Cannot provide {details} if {container} is given'
            msg += ', {container}:`{plain}`, {container}_required:`{required}`, {container}_optional:`{optional}`'

            raise ValueError(msg.format(**{
                'details': details,
                'container': container,
                'plain': plain,
                'required': required,
                'optional': optional
            }))

        # It is possible that nothing is to be given on input or produced, which is fine, we do not reject it
        # but there is no reason to continue either.
        if not (plain or required or optional):
            return

        # Listify all the elements provided
        if isinstance(plain, basestring):
            plain = [plain]

        if isinstance(required, basestring):
            required = [required]

        if isinstance(optional, basestring):
            optional = [optional]

        # At this point we have either a list of plain elements or input_required/input_optional, but not both.
        # In the former case, we need to build required and optional lists manually by extracting
        # all the elements from the plain list.
        if plain:

            prefix_optional = self.server_config.prefix_optional

            for elem in plain:

                is_sio_elem = isinstance(elem, Elem)
                elem_name = elem.name if is_sio_elem else elem

                if elem_name.startswith(prefix_optional):
                    elem_name_no_prefix = elem_name.replace(prefix_optional, '')
                    if is_sio_elem:
                        elem.name = elem_name_no_prefix
                    optional.append(elem if is_sio_elem else elem_name_no_prefix)
                else:
                    required.append(elem if is_sio_elem else elem_name)

        # So that in runtime elements are always checked in the same order
        required = sorted(required)
        optional = sorted(optional)

        # Now, convert all elements to Elem instances
        _required = []
        _optional = []

        elems = (
            (required, True),
            (optional, False),
        )

        for elem_list, is_required in elems:
            for elem in elem_list:
                if not isinstance(elem, Elem):
                    elem = self._convert_to_elem_instance(elem, container, is_required)
                if is_required:
                    _required.append(elem)
                else:
                    _optional.append(elem)

        required = _required
        optional = _optional

        # Confirm that required elements do not overlap with optional ones
        shared_elems = set(elem.name for elem in required) & set(elem.name for elem in optional)

        if shared_elems:
            raise ValueError('Elements in input_required and input_optional cannot be shared, found:`{}`'.format(
                sorted(elem.encode('utf8') for elem in shared_elems)))

        # Everything is validated, we can actually set the lists of elements now

        container_req_name = '_{}_required'.format(container)
        container_required = getattr(self.definition, container_req_name)
        container_required.set_elems(required)

        container_opt_name = '_{}_optional'.format(container)
        container_optional = getattr(self.definition, container_opt_name)
        container_optional.set_elems(optional)

# ################################################################################################################################

    @staticmethod
    def attach_sio(server_config, class_):
        """ Given a service class, the method extracts its user-defined SimpleIO definition
        and attaches the Cython-based one to the class's _sio attribute.
        """

        # Get the user-defined SimpleIO definition
        user_sio = getattr(class_, 'SimpleIO', None)

        # This class does not use SIO so we can just return immediately
        if not user_sio:
            return

        # Attach the Cython object representing the parsed user definition
        cy_simple_io = CySimpleIO(server_config, user_sio)
        cy_simple_io.build()
        class_._sio = cy_simple_io

# ################################################################################################################################

    cdef dict _parse_input_elem(self, dict elem, unicode data_format, object _default=object()):

        cdef dict out = {}

        for sio_item in chain(self.definition._input_required, self.definition._input_optional):
            input_value = elem.get(sio_item.name, _default)

            # We do not have such a key on input so an exception needs to be raised if this is a require one
            if input_value is _default:
                if sio_item.is_required:
                    raise ValueError('No such key `{}` among `{}` in `{}`'.format(sio_item.name, elem.keys(), elem))
                else:
                    value = 'ZZZ'
            else:
                parse_func = sio_item.parse_from[data_format]
                value = parse_func(input_value)

            out[sio_item.name] = value

        return out

# ################################################################################################################################

    cpdef parse_input(self, data, data_format):

        if isinstance(data, list):
            out = []
            for elem in data:
                converted = self._parse_input_elem(elem, data_format)
                out.append(bunchify(converted))
            return out
        else:
            out = self._parse_input_elem(data, data_format)
            return bunchify(out)

# ################################################################################################################################

# Create server/process-wide singletons
NotGiven = _NotGiven()

# ################################################################################################################################
