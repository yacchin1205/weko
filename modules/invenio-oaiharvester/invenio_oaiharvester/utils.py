# -*- coding: utf-8 -*-
#
# This file is part of Invenio.
# Copyright (C) 2014, 2015, 2016 CERN.
#
# Invenio is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Invenio is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Invenio; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

"""OAI harvest utils."""

from __future__ import absolute_import, print_function, unicode_literals
import codecs
import enum
import itertools
import os
import re
import tempfile
from builtins import bytes
from collections import namedtuple
from contextlib import closing
from datetime import datetime
from socket import socket
from urllib.parse import urlparse
import idna
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from flask import current_app
from invenio_cache.proxies import current_cache
from lxml import etree
from OpenSSL import SSL
from .config import OAIHARVESTER_SELF_CERTIFICATE_FILE
from .errors import InvenioOAIHarvesterConfigNotFound

REGEXP_OAI_ID = re.compile(r"<identifier.*?>(.*?)</identifier>", re.DOTALL)


class ItemEvents(enum.IntEnum):
    """Item process event."""

    INIT = 0
    CREATE = 1
    UPDATE = 2
    DELETE = 3
    ERROR = 9


def record_extraction_from_file(
        path,
        oai_namespace="http://www.openarchives.org/OAI/2.0/"):
    """Given a harvested file return a list of every record incl. headers.

    :param path: is the path of the file harvested
    :type path: str

    :param oai_namespace: optionally provide the OAI-PMH namespace
    :type oai_namespace: str

    :return: return a list of XML records as string
    :rtype: str
    """
    list_of_records = []
    with open(path) as xml_file:
        list_of_records = record_extraction_from_string(
            xml_file.read(), oai_namespace
        )
    return list_of_records


def record_extraction_from_string(
        xml_string,
        oai_namespace="http://www.openarchives.org/OAI/2.0/"):
    """Given a OAI-PMH XML return a list of every record incl. headers.

    :param xml_string: OAI-PMH XML
    :type xml_string: str

    :param oai_namespace: optionally provide the OAI-PMH namespace
    :type oai_namespace: str

    :return: return a list of XML records as string
    :rtype: str
    """
    if oai_namespace:
        nsmap = {
            'OAI-PMH': oai_namespace
        }
    else:
        nsmap = current_app.config.get("OAIHARVESTER_DEFAULT_NAMESPACE_MAP")
    namespace_prefix = "{{{0}}}".format(oai_namespace)
    root = etree.fromstring(xml_string)
    headers = []
    headers.extend(
        root.findall(".//{0}responseDate".format(namespace_prefix), nsmap)
    )
    headers.extend(
        root.findall(".//{0}request".format(namespace_prefix), nsmap)
    )

    records = root.findall(".//{0}record".format(namespace_prefix), nsmap)

    list_of_records = []
    for record in records:
        wrapper = etree.Element("OAI-PMH", nsmap=nsmap)
        for header in headers:
            wrapper.append(header)
        wrapper.append(record)
        list_of_records.append(etree.tostring(wrapper))
    return list_of_records


def identifier_extraction_from_string(
        xml_string,
        oai_namespace="http://www.openarchives.org/OAI/2.0/"):
    """Given a OAI-PMH XML string return the OAI identifier.

    :param xml_string: OAI-PMH XML
    :type xml_string: str

    :param oai_namespace: optionally provide the OAI-PMH namespace
    :type oai_namespace: str

    :return: OAI identifier
    :rtype: str
    """
    if oai_namespace:
        nsmap = {
            'OAI-PMH': oai_namespace
        }
    else:
        nsmap = current_app.config.get("OAIHARVESTER_DEFAULT_NAMESPACE_MAP")
    namespace_prefix = "{{{0}}}".format(oai_namespace)
    root = etree.fromstring(xml_string)
    node = root.find(".//{0}identifier".format(namespace_prefix), nsmap)
    if node is not None:
        return node.text


def get_identifier_names(identifiers):
    """Return list of identifiers from a comma-separated string."""
    if identifiers is not None:
        if not isinstance(identifiers, (list, tuple)):
            identifiers = identifiers.split(',')
        return [s.strip() for s in identifiers]
    return []


def get_oaiharvest_object(name):
    """Query and returns an OAIHarvestConfig object based on its name.

    :param name: The name of the OAIHarvestConfig object.
    :return: The OAIHarvestConfig object.
    """
    from .models import OAIHarvestConfig
    obj = OAIHarvestConfig.query.filter_by(name=name).first()
    if not obj:
        raise InvenioOAIHarvesterConfigNotFound(
            'Unable to find OAIHarvesterConfig obj with name %s.'
            % name
        )

    return obj


def check_or_create_dir(output_dir):
    """Check whether the directory exists, and creates it if not.

    :param output_dir: The directory where the output should be sent.
    :return:
    """
    default = os.path.join(
        current_app.config["OAIHARVESTER_WORKDIR"] or tempfile.gettempdir(),
        "oaiharvester"
    )
    path = os.path.join(default, output_dir)

    if not os.path.exists(path):
        os.makedirs(path)

    return path


def create_file_name(output_dir):
    """Create a random file name.

    :param output_dir: The directory where the file should be created.
    :return: random filename
    """
    prefix = 'oaiharvest_' + datetime.now().strftime('%Y-%m-%d') + '_'

    with closing(
        tempfile.NamedTemporaryFile(
            prefix=prefix,
            suffix='.xml',
            dir=output_dir,
            mode='w+'
        )
    ) as temp:
        file_name = temp.name[:]

    return file_name


def chunks(iterable, size):
    """Yield successive chunks of specific size from iterable."""
    iterable = iter(iterable)
    while True:
        chunk = tuple(itertools.islice(iterable, size))
        if not chunk:
            return
        yield chunk


def write_to_dir(records, output_dir, max_records=1000, encoding='utf-8'):
    """Check if the output directory exists, and creates it if it does not.

    :param records: harvested records.
    :param output_dir: directory where the output should be sent.
    :param max_records: max number of records to be written in a single file.

    :return: paths to files created, total number of records
    """
    if not records:
        return [], 0

    output_path = check_or_create_dir(output_dir)
    files_created = []
    total = 0  # total number of records processed

    for chunk in chunks(records, max_records):
        files_created.append(create_file_name(output_path))
        with codecs.open(files_created[-1], 'w+', encoding=encoding) as f:
            f.write('<ListRecords>')
            for record in chunk:
                f.write(record.raw)
                total += 1
            f.write('</ListRecords>')

    return files_created, total


def analyze_url(url):
    """Analyze an url then return scheme, host name and host."""
    host_info = urlparse(url)
    scheme, host, port = host_info.scheme, host_info.hostname, host_info.port
    if not port and scheme == 'https':
        port = 443
    return scheme, host, port


def get_certificate(hostname, port):
    """Get certificate of a site."""
    HostInfo = namedtuple(field_names='cert hostname peername', typename='HostInfo')

    hostname_idna = idna.encode(hostname)
    sock = socket()

    sock.connect((hostname, port))
    peer_name = sock.getpeername()
    ctx = SSL.Context(SSL.SSLv23_METHOD)  # most compatible
    ctx.check_hostname = False
    ctx.verify_mode = SSL.VERIFY_NONE

    sock_ssl = SSL.Connection(ctx, sock)
    sock_ssl.set_connect_state()
    sock_ssl.set_tlsext_host_name(hostname_idna)
    sock_ssl.do_handshake()
    cert = sock_ssl.get_peer_certificate()
    crypto_cert = cert.to_cryptography()
    sock_ssl.close()
    sock.close()

    return HostInfo(cert=crypto_cert, peername=peer_name, hostname=hostname)


def load_self_cert():
    """Load self cert."""
    with os.open(OAIHARVESTER_SELF_CERTIFICATE_FILE) as crt_file:
        crt_data = crt_file.read()
    cert = x509.load_pem_x509_certificate(bytes(crt_data, encoding='utf8'), default_backend())
    return cert


def get_verify(url):
    """Check url to detect whether set verify as True or False"""
    try:
        scheme, host, port = analyze_url(url)
        if scheme == 'http':
            return False
        site_crt = get_certificate(host, port)
        self_crt = load_self_cert()
        verify = site_crt.cert != self_crt
    except Exception as ex:
        current_app.logger.error(str(ex))
        verify = False
    return verify
