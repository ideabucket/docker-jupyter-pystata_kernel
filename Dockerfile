#syntax=docker/dockerfile:1

# TODO: figure out how to slim the final image down

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

# first, unpack the supplied stata tarball and install it. the tarball 
# includes an install script, but it is mostly about checking for things
# we can assume thanks to the controlled build environment. the only 
# substantive thing it does is unpack four .tar.Z files and run a 
# non-interactive permissions-setting script. we can do that ourselves 
# and so we do.
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
	cp ${taz_path}/setrwxp ${stata_target_dir} && \
	/bin/bash -c "cd ${stata_target_dir} && ./setrwxp now" && \
	chmod g+w -R ${stata_target_dir} && \
	chgrp users -R ${stata_target_dir} && \
	rm -rf ${stata_install_dir}

# put the stata.lic file in the right place. 
# TODO: it should be possible to construct the license file from build_args.
COPY ${license_file} ${stata_target_dir}/	

# stata expects some legacy ncurses libraries
RUN apt-get update && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# now we get stata to update to the latest version. this is messy because: 
#
# 1. stata is a bad unix citizen and exits with a zero return code even if
#    if a batch mode command (in this case, update) fails
# 2. statacorp's update servers are horribly slow and letting stata fetch
#    the install files itself can result in undetectable timeouts (see #1)
# 3. there is what appears to be a bug in the part of stata's internal update
#    procedure which moves the old versions of the utilities/ subfolders 
#    out of the way which causes the whole update to abort when it tries 
#    (see https://www.stata.com/support/faqs/web/common-update-error-messages/)
# 4. the update process is prone to mess up permissions
#
# so in order to work around this we:
#
# A. fetch the current stata update file with wget and have stata update from 
#    a local copy (this could fail if statacorp change the URL)
# B. manually delete the old utilities/ subfolders so the update can't choke
#    on them
# C. rerun the permissions-setting script from the base install
RUN mkdir -m 775 /tmp/stata_update && \
	wget --quiet --directory-prefix=/tmp \
		https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar && \
	tar --extract --no-same-owner --directory=/tmp/stata_update \
		--strip-components=1 \
		--file=/tmp/stata${stata_version}update_linux64.tar && \
	rm -rf ${stata_target_dir}/utilities/jar && \
	rm -rf ${stata_target_dir}/utilities/java && \
	rm -rf ${stata_target_dir}/utilities/pystata && \
	${stata_target_dir}/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c \
		"cd ${stata_target_dir} && ./setrwxp now" && \
	chmod g+w -R $stata_target_dir && \
	chgrp users -R $stata_target_dir && \
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
