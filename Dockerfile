# -*- coding: utf-8 -*-
# Copyright (c) 2017 National Institute of Informatics.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions
#  and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
#  and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products
#  derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Use Python-3.7:
FROM python:3.9-slim-buster as stage_1

# Configure Weko instance:
ENV INVENIO_WEB_HOST=127.0.0.1
ENV INVENIO_WEB_INSTANCE=invenio
ENV INVENIO_WEB_VENV=invenio
ENV INVENIO_WEB_HOST_NAME=invenio
ENV INVENIO_USER_EMAIL=wekosoftware@nii.ac.jp
ENV INVENIO_USER_PASS=uspass123
ENV INVENIO_POSTGRESQL_HOST=postgresql
ENV INVENIO_POSTGRESQL_DBNAME=invenio
ENV INVENIO_POSTGRESQL_DBUSER=invenio
ENV INVENIO_POSTGRESQL_DBPASS=dbpass123
ENV INVENIO_REDIS_HOST=redis
ENV INVENIO_ELASTICSEARCH_HOST=elasticsearch
ENV INVENIO_RABBITMQ_HOST=rabbitmq
ENV INVENIO_RABBITMQ_USER=guest
ENV INVENIO_RABBITMQ_PASS=guest
ENV INVENIO_RABBITMQ_VHOST=/
ENV INVENIO_WORKER_HOST=127.0.0.1
ENV SEARCH_INDEX_PREFIX=tenant1
ENV INVENIO_WEB_PROTOCOL=https
ENV CACHE_REDIS_DB=0
ENV ACCOUNTS_SESSION_REDIS_DB_NO=1
ENV CELERY_RESULT_BACKEND_DB_NO=2
ENV WEKO_AGGREGATE_EVENT_HOUR=0
ENV WEKO_AGGREGATE_EVENT_MINUTE=0

# Configure SQLAlchemy connection pool
# see: https://docs.sqlalchemy.org/en/12/core/pooling.html#api-documentation-available-pool-implementations
ENV INVENIO_DB_POOL_CLASS=QueuePool

FROM stage_1 AS stage_2
# Install Weko web node pre-requisites:
COPY scripts/provision-web.sh /tmp/
RUN /tmp/provision-web.sh

FROM stage_2 AS stage_3
# Add Weko sources to `code` and work there:
WORKDIR /code
RUN adduser --uid 1000 --disabled-password --gecos '' invenio
USER invenio
COPY --chown=invenio:invenio tools /code/tools
RUN pip install --no-cache-dir -U pip setuptools wheel

# Install Weko web node modules:
COPY --chown=invenio:invenio constraints.txt /code/constraints.txt
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    mkvirtualenv "${INVENIO_WEB_VENV}"'

# invenio-db
COPY --chown=invenio:invenio modules/invenio-db /code/modules/invenio-db
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        -e file://localhost/code/modules/invenio-db#egg=invenio_db'
# invenio-records
COPY --chown=invenio:invenio modules/invenio-records /code/modules/invenio-records
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        -e file://localhost/code/modules/invenio-records#egg=invenio_records'
# invenio-files-rest
COPY --chown=invenio:invenio modules/invenio-files-rest /code/modules/invenio-files-rest
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        -e file://localhost/code/modules/invenio-files-rest#egg=invenio_files_rest'
# invenio-accounts
COPY --chown=invenio:invenio modules/invenio-accounts /code/modules/invenio-accounts
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        -e file://localhost/code/modules/invenio-accounts#egg=invenio_accounts'
# invenio-oauth2server
COPY --chown=invenio:invenio modules/invenio-oauth2server /code/modules/invenio-oauth2server
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        -e file://localhost/code/modules/invenio-oauth2server#egg=invenio_oauth2server'
# invenio-indexer
COPY --chown=invenio:invenio modules/invenio-indexer /code/modules/invenio-indexer
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-indexer#egg=invenio_indexer'
# invenio-records-rest
COPY --chown=invenio:invenio modules/invenio-records-rest /code/modules/invenio-records-rest
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-records-rest#egg=invenio_records_rest'
# invenio-deposit
COPY --chown=invenio:invenio modules/invenio-deposit /code/modules/invenio-deposit
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-deposit#egg=invenio_deposit'
# invenio-queues
COPY --chown=invenio:invenio modules/invenio-queues /code/modules/invenio-queues
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-queues#egg=invenio_queues'
# invenio-stats
COPY --chown=invenio:invenio modules/invenio-stats /code/modules/invenio-stats
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-stats#egg=invenio_stats'
# invenio-iiif
COPY --chown=invenio:invenio modules/invenio-iiif /code/modules/invenio-iiif
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-iiif#egg=invenio_iiif'
# invenio-mail
COPY --chown=invenio:invenio modules/invenio-mail /code/modules/invenio-mail
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-mail#egg=invenio_mail'
# invenio-oaiharvester
COPY --chown=invenio:invenio modules/invenio-oaiharvester /code/modules/invenio-oaiharvester
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-oaiharvester#egg=invenio_oaiharvester'
# invenio-oaiserver
COPY --chown=invenio:invenio modules/invenio-oaiserver /code/modules/invenio-oaiserver
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-oaiserver#egg=invenio_oaiserver'
# invenio-previewer
COPY --chown=invenio:invenio modules/invenio-previewer /code/modules/invenio-previewer
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-previewer#egg=invenio_previewer'
# invenio-resourcesyncclient
COPY --chown=invenio:invenio modules/invenio-resourcesyncclient /code/modules/invenio-resourcesyncclient
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-resourcesyncclient#egg=invenio_resourcesyncclient'
# invenio-resourcesyncserver
COPY --chown=invenio:invenio modules/invenio-resourcesyncserver /code/modules/invenio-resourcesyncserver
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-resourcesyncserver#egg=invenio_resourcesyncserver'
# invenio-s3
COPY --chown=invenio:invenio modules/invenio-s3 /code/modules/invenio-s3
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/invenio-s3#egg=invenio_s3'
# weko-accounts
COPY --chown=invenio:invenio modules/weko-accounts /code/modules/weko-accounts
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-accounts#egg=weko_accounts'
# weko-admin
COPY --chown=invenio:invenio modules/weko-admin /code/modules/weko-admin
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-admin#egg=weko_admin'
# weko-authors
COPY --chown=invenio:invenio modules/weko-authors /code/modules/weko-authors
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-authors#egg=weko_authors'
# weko-bulkupdate
COPY --chown=invenio:invenio modules/weko-bulkupdate /code/modules/weko-bulkupdate
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-bulkupdate#egg=weko_bulkupdate'
# weko-deposit
COPY --chown=invenio:invenio modules/weko-deposit /code/modules/weko-deposit
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-deposit#egg=weko_deposit'
# weko-gridlayout
COPY --chown=invenio:invenio modules/weko-gridlayout /code/modules/weko-gridlayout
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-gridlayout#egg=weko_gridlayout'
# weko-groups
COPY --chown=invenio:invenio modules/weko-groups /code/modules/weko-groups
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-groups#egg=weko_groups'
# weko-handle
COPY --chown=invenio:invenio modules/weko-handle /code/modules/weko-handle
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-handle#egg=weko_handle'
# weko-index-tree
COPY --chown=invenio:invenio modules/weko-index-tree /code/modules/weko-index-tree
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-index-tree#egg=weko_index_tree'
# weko-indextree-journal
COPY --chown=invenio:invenio modules/weko-indextree-journal /code/modules/weko-indextree-journal
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-indextree-journal#egg=weko_indextree_journal'
# weko-items-autofill
COPY --chown=invenio:invenio modules/weko-items-autofill /code/modules/weko-items-autofill
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-items-autofill#egg=weko_items_autofill'
# weko-items-ui
COPY --chown=invenio:invenio modules/weko-items-ui /code/modules/weko-items-ui
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-items-ui#egg=weko_items_ui'
# weko-itemtypes-ui
COPY --chown=invenio:invenio modules/weko-itemtypes-ui /code/modules/weko-itemtypes-ui
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-itemtypes-ui#egg=weko_itemtypes_ui'
# weko-logging
COPY --chown=invenio:invenio modules/weko-logging /code/modules/weko-logging
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-logging#egg=weko_logging'
# weko-plugins
COPY --chown=invenio:invenio modules/weko-plugins /code/modules/weko-plugins
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-plugins#egg=weko_plugins'
# weko-records
COPY --chown=invenio:invenio modules/weko-records /code/modules/weko-records
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-records#egg=weko_records'
# weko-records-ui
COPY --chown=invenio:invenio modules/weko-records-ui /code/modules/weko-records-ui
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-records-ui#egg=weko_records_ui'
# weko-redis
COPY --chown=invenio:invenio modules/weko-redis /code/modules/weko-redis
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-redis#egg=weko_redis'
# weko-schema-ui
COPY --chown=invenio:invenio modules/weko-schema-ui /code/modules/weko-schema-ui
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-schema-ui#egg=weko_schema_ui'
# weko-search-ui
COPY --chown=invenio:invenio modules/weko-search-ui /code/modules/weko-search-ui
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-search-ui#egg=weko_search_ui'
# weko-sitemap
COPY --chown=invenio:invenio modules/weko-sitemap /code/modules/weko-sitemap
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-sitemap#egg=weko_sitemap'
# weko-swordserver
COPY --chown=invenio:invenio modules/weko-swordserver /code/modules/weko-swordserver
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-swordserver#egg=weko_swordserver'
# weko-theme
COPY --chown=invenio:invenio modules/weko-theme /code/modules/weko-theme
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-theme#egg=weko_theme'
# weko-user-profiles
COPY --chown=invenio:invenio modules/weko-user-profiles /code/modules/weko-user-profiles
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-user-profiles#egg=weko_user_profiles'
# weko-workflow
COPY --chown=invenio:invenio modules/weko-workflow /code/modules/weko-workflow
RUN bash -c 'source "$(which virtualenvwrapper.sh)" && \
    workon "${INVENIO_WEB_VENV}" && \
    cdvirtualenv && \
    pip install --no-cache-dir -c /code/constraints.txt \
        file://localhost/code/modules/weko-workflow#egg=weko_workflow'

# Install remaining Weko web node modules
COPY --chown=invenio:invenio modules /code/modules
COPY --chown=invenio:invenio scripts/pip-install-modules.sh /code/scripts/pip-install-modules.sh
RUN chmod +x /code/scripts/pip-install-modules.sh && \
    bash -c 'source "$(which virtualenvwrapper.sh)" && \
        workon "${INVENIO_WEB_VENV}" && \
        cdvirtualenv && \
        /code/scripts/pip-install-modules.sh'

COPY --chown=invenio:invenio packages-invenio.txt /code/packages-invenio.txt
COPY --chown=invenio:invenio requirements-weko-modules.txt /code/requirements-weko-modules.txt
COPY --chown=invenio:invenio invenio /code/invenio
COPY --chown=invenio:invenio postgresql /code/postgresql
COPY --chown=invenio:invenio scripts /code/scripts

FROM stage_3 AS stage_4
# Create Weko instance:
RUN chmod +x /code/scripts/create-instance.sh /code/scripts/pip-install-modules.sh; /code/scripts/create-instance.sh



FROM stage_4 AS stage_5
# Create Weko instance2:
USER invenio
WORKDIR /code
COPY --chown=invenio:invenio scripts/instance.cfg /code/scripts/instance.cfg
RUN chmod +x /code/scripts/create-instance2.sh;/code/scripts/create-instance2.sh

FROM stage_5 AS build-env
# Make given VENV default:
ENV PATH=/home/invenio/.virtualenvs/invenio/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#ENV VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python
ENV VIRTUALENVWRAPPER_PYTHON=/home/invenio/.virtualenvs/invenio/bin/python
#RUN echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc ; echo "workon invenio" >> ~/.bashrc
RUN pip install virtualenvwrapper
RUN echo "source /home/invenio/.virtualenvs/invenio/bin/virtualenvwrapper.sh" >> ~/.bashrc ; echo "workon invenio" >> ~/.bashrc

#RUN mv /home/invenio/.virtualenvs/invenio/var/instance/static /home/invenio/.virtualenvs/invenio/var/instance/static.org

# CMD ["/bin/bash", "-c", "gunicorn invenio_app.wsgi --workers=4 --worker-class=meinheld.gmeinheld.MeinheldWorker -b 0.0.0.0:5000 "]
#CMD ["/bin/bash","-c","uwsgi --ini /code/scripts/uwsgi.ini"]
CMD ["/bin/bash", "-c", "invenio run -h 0.0.0.0"]

# FROM python:3.6-slim-buster as product-base
# RUN apt-get -y update --allow-releaseinfo-change;apt-get -y --no-install-recommends install curl rlwrap screen vim gnupg libpcre3 libffi6 libfreetype6 libmsgpackc2 libssl1.1 libtiff5 libxml2 libxslt1.1 libzip4 nodejs libpq5 default-jre libreoffice-java-common libreoffice fonts-ipafont fonts-ipaexfont git
# COPY --from=build-env /usr/bin /usr/bin
# COPY --from=build-env /usr/lib/node_modules /usr/lib/node_modules
# RUN adduser --uid 1000 --disabled-password --gecos '' invenio
# USER invenio
# WORKDIR /code
# COPY --from=build-env --chown=invenio:invenio /code /code
# COPY --from=build-env --chown=invenio:invenio /home/invenio/.virtualenvs /home/invenio/.virtualenvs
#RUN mv /home/invenio/.virtualenvs/invenio/var/instance/static /home/invenio/.virtualenvs/invenio/var/instance/static.org
# CMD ["/bin/bash"]
# CMD ["/bin/bash", "-c", "invenio run -h 0.0.0.0"]

# FROM python:3.6-slim-buster as product-env
# # Configure Weko instance:
# ENV INVENIO_WEB_HOST=127.0.0.1
# ENV INVENIO_WEB_INSTANCE=invenio
# ENV INVENIO_WEB_VENV=invenio
# ENV INVENIO_WEB_HOST_NAME=invenio
# ENV INVENIO_USER_EMAIL=wekosoftware@nii.ac.jp
# ENV INVENIO_USER_PASS=uspass123
# ENV INVENIO_POSTGRESQL_HOST=postgresql
# ENV INVENIO_POSTGRESQL_DBNAME=invenio
# ENV INVENIO_POSTGRESQL_DBUSER=invenio
# ENV INVENIO_POSTGRESQL_DBPASS=dbpass123
# ENV INVENIO_REDIS_HOST=redis
# ENV INVENIO_ELASTICSEARCH_HOST=elasticsearch
# ENV INVENIO_RABBITMQ_HOST=rabbitmq
# ENV INVENIO_RABBITMQ_USER=guest
# ENV INVENIO_RABBITMQ_PASS=guest
# ENV INVENIO_RABBITMQ_VHOST=/
# ENV INVENIO_WORKER_HOST=127.0.0.1
# ENV SEARCH_INDEX_PREFIX=tenant1
# # Configure SQLAlchemy connection pool
# # see: https://docs.sqlalchemy.org/en/12/core/pooling.html#api-documentation-available-pool-implementations
# ENV INVENIO_DB_POOL_CLASS=QueuePool

# RUN apt-get -y update && apt-get -y install curl nano default-jre libreoffice libreoffice-java-common fonts-ipafont fonts-ipaexfont --no-install-recommends && apt-get -y clean && pip install -U setuptools pip virtualenvwrapper && adduser --uid 1000 --disabled-password --gecos '' invenio
# USER invenio
# COPY --from=build-env --chown=invenio:invenio /home/invenio/.virtualenvs /home/invenio/.virtualenvs
# COPY --from=build-env --chown=invenio:invenio /code /code
# COPY --from=build-env /usr/bin /usr/bin

# ENV PATH=/home/invenio/.virtualenvs/invenio/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# ENV VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python
# RUN echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc && echo "workon invenio" >> ~/.bashrc
# WORKDIR /code

# CMD ["/bin/bash", "-c", "invenio run -h 0.0.0.0"]


