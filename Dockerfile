#syntax=docker/dockerfile:1

# substitute jupyter/r-notebook:latest if you want an R kernel as well
FROM jupyter/minimal-notebook:latest

ARG stata_version=17
ARG stata_tarball=rsrc/Stata${stata_version}Linux64.tar.gz
ARG license_file=rsrc/stata.lic

ARG stata_install_dir=/tmp/stata_install

# to build image with the dev kernel instead, override this arg with
# git+https://github.com/ticoneva/pystata-kernel.git
ARG kernel_pkgname=pystata-kernel

ARG stata_target_dir=/usr/local/stata${stata_version}

# this path has changed between versions before and might do so again
ARG taz_path=${stata_install_dir}/unix/linux64

# these args populate the config file
ARG stata_edition=be
ARG graph_format=pystata
ARG echo_behavior=False
ARG splash_behavior=False

EXPOSE 8888/tcp

USER root 

ADD ${stata_tarball} ${stata_install_dir}

RUN mkdir ${stata_target_dir} && \
	ln -s ${stata_target_dir} /usr/local/stata && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/base.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/bins.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/ado.taz && \
	tar --extract --no-same-owner --directory=${stata_target_dir} \
			--file=${taz_path}/docs.taz && \
	/bin/bash -c \
		"cd ${stata_target_dir} && ${taz_path}/setrwxp now" && \
	chmod g+w -R $stata_target_dir && \
	chgrp users -R $stata_target_dir
	
COPY ${license_file} ${stata_target_dir}

# stata expects some legacy ncurses libraries
RUN apt-get update && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# stata's internal upgrade command is far too temperamental, and their servers
# are exasperatingly slow, so we fetch the latest update file directly and have
# stata upgrade from it (and then we have to fix the permissions again because
# the update makes a mess of them)
ADD https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar \
		/tmp/

# stata's update process has something wrong with the routine that's
# meant to handle moving the old versions of the utilities/ folders
# out of the way which means it fails if they exist, so we monkeypatch
# the install to get rid of them
# see https://www.stata.com/support/faqs/web/common-update-error-messages/
RUN mkdir -m 775 /tmp/stata_update && \
	tar --extract --no-same-owner --directory=/tmp/stata_update \
		--strip-components=1 \
		--file=/tmp/stata${stata_version}update_linux64.tar && \
	rm -rf ${stata_target_dir}/utilities/jar && \
	rm -rf ${stata_target_dir}/utilities/java && \
	rm -rf ${stata_target_dir}/utilities/pystata && \
	${stata_target_dir}/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c \
		"cd ${stata_target_dir} && ${taz_path}/setrwxp now" && \
	chmod g+w -R $stata_target_dir && \
	chgrp users -R $stata_target_dir && \
	rm -rf ${stata_install_dir} && \
	rm -rf /tmp/stata${stata_version}update_linux64.tar && \
	rm -rf /tmp/stata_update

# NB_UID arg is inherited from the official Jupyter dockerfiles
USER ${NB_UID}

ENV PATH=${stata_target_dir}:$PATH
ENV JUPYTER_ENABLE_LAB=yes

RUN pip install ${kernel_pkgname} && \
	python -m pystata-kernel.install && \
	conda install -c conda-forge jupyterlab-git nodejs -y && \
	jupyter labextension install jupyterlab-stata-highlight
	
# heredocs depend on syntax v1.4+
COPY <<-EOF /home/${NB_USER}/.pystata-kernel.conf
	[pystata-kernel]
	stata_dir = ${stata_target_dir}
	edition = ${stata_edition}
	graph_format = ${graph_format}
	echo = ${echo_behavior}
	splash = ${splash_behavior}
EOF
