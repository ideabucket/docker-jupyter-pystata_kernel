#syntax=docker/dockerfile:1

# substitute jupyter/r-notebook:latest if you want an R kernel as well
FROM jupyter/minimal-notebook:latest

ARG stata_version=17
ARG license_file=rsrc/stata.lic

# Downloading from the official website requires special credentials, so
# we assume your employer or university has probably done this and given you
# the URL of a cached copy. If this is not the case, you will need to use
# your personal license credentials to download the tarball from 
# https://download.stata.com/download/linux64_17/ and put it somewhere
# accessible to anonymous wget. 
ARG stata_base_tarball=""
ARG stata_update_tarball="https://www.stata.com/support/updates/stata${stata_version}/stata${stata_version}update_linux64.tar"

ARG stata_install_dir=/tmp/stata_install
ARG stata_target_dir=/usr/local/stata${stata_version}

# to build image with the dev kernel instead, override this arg with
# git+https://github.com/ticoneva/pystata-kernel.git
ARG kernel_pkgname=pystata-kernel

# this path has changed between versions before and might do so again
ARG taz_path=${stata_install_dir}/unix/linux64

# these args populate the config file
ARG stata_edition=be
ARG graph_format=pystata
ARG echo_behavior=False
ARG splash_behavior=False

EXPOSE 8888/tcp

USER root 

COPY ${license_file} /tmp/

# all this mess does the following things:
# 
# 1. fetches the base stata tarball that your university or employer has 
#    supplied, which is probably out of date
# 2. unpacks it in the same way the install script would
# 3. copies your stata.lic into place
# 4. installs some legacy ncurses libraries stata needs to run
# 5. fetches the most recent stata update tarball from statacorp's website
# 6. monkeypatches the stata install to work around a bug in stata's internal
#    update process (for which, see
#    https://www.stata.com/support/faqs/web/common-update-error-messages/)
# 7. tells stata to update itself from the local copy of the tarball
#    (because if we let stata fetch the update itself and it fails, it fails
#    in a way that the build process can't easily detect, so it doesn't abort)
# 8. fixes permissions and cleans up after itself
#
# it does all this in one horror command chain because breaking it up would
# result in a 2+Gb increase in the final image size
RUN mkdir ${stata_install_dir} && \
	mkdir ${stata_target_dir} && \
	ln -s ${stata_target_dir} /usr/local/stata && \
	wget --output-document=/tmp/stata_linux.tar \
		 	--no-verbose -- ${stata_base_tarball} && \
	tar --extract --no-same-owner --directory=${stata_install_dir} \
			--file=/tmp/stata_linux.tar && \
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
	mv /tmp/stata.lic ${stata_target_dir}/stata.lic && \
	rm -rf ${stata_install_dir} && \
	apt-get update && \
	apt-get install --no-install-recommends -y libtinfo5 libncurses5 && \
	apt-get -y upgrade && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	mkdir -m 775 /tmp/stata_update && \
	wget --output-document=/tmp/stata_update.tar \
			--quiet -- ${stata_update_tarball} && \
	tar --extract --no-same-owner --directory=/tmp/stata_update \
			--strip-components=1 \
			--file=/tmp/stata_update.tar && \
	rm -rf ${stata_target_dir}/utilities/jar && \
	rm -rf ${stata_target_dir}/utilities/java && \
	rm -rf ${stata_target_dir}/utilities/pystata && \
	${stata_target_dir}/stata -q \
		-b 'update all, force from("/tmp/stata_update")' && \
	/bin/bash -c "cd ${stata_target_dir} && ./setrwxp now" && \
	rm -rf /tmp/stata_update.tar && \
	rm -rf /tmp/stata_update && \
	rm ${stata_target_dir}/setrwxp


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
